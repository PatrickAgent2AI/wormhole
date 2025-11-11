#!/usr/bin/env node

/**
 * 完整Relayer - 获取VAA并提交到链上合约
 * 
 * 支持两种模式：
 * 1. EVM链 - 调用Token Bridge的completeTransfer
 * 2. 验证模式 - 仅验证VAA并显示信息
 */

const ethers = require('ethers');

// 配置
const CONFIG = {
    guardianRestApi: process.env.GUARDIAN_REST_API || 'http://localhost:7071',
    rpcUrl: process.env.RPC_URL || 'http://localhost:8545',
    coreBridgeAddress: process.env.CORE_BRIDGE || '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
    tokenBridgeAddress: process.env.TOKEN_BRIDGE || '0x0165878A594ca255338adfa4d48449f69242Eb8F',
    chainId: 2,
    emitterAddress: '000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266',
    pollInterval: 5000,
    submitToChain: process.env.SUBMIT_TO_CHAIN === 'true', // 是否真正提交到链上
};

// Core Bridge ABI
const CORE_BRIDGE_ABI = [
    'function parseAndVerifyVM(bytes calldata encodedVM) external view returns (tuple(uint8 version, uint32 timestamp, uint32 nonce, uint16 emitterChainId, bytes32 emitterAddress, uint64 sequence, uint8 consistencyLevel, bytes payload, uint32 guardianSetIndex, tuple(bytes32 r, bytes32 s, uint8 v, uint8 guardianIndex)[] signatures, bytes32 hash) vm, bool valid, string memory reason)',
];

// Token Bridge ABI
const TOKEN_BRIDGE_ABI = [
    'function completeTransfer(bytes memory encodedVm) public',
];

class RelayerWithSubmit {
    constructor() {
        this.provider = new ethers.providers.JsonRpcProvider(CONFIG.rpcUrl);
        this.processedSequences = new Set();
        this.latestSequence = -1;
        
        const privateKey = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
        this.wallet = new ethers.Wallet(privateKey, this.provider);
        
        this.coreBridge = new ethers.Contract(CONFIG.coreBridgeAddress, CORE_BRIDGE_ABI, this.wallet);
        this.tokenBridge = new ethers.Contract(CONFIG.tokenBridgeAddress, TOKEN_BRIDGE_ABI, this.wallet);
        
        console.log('✅ Relayer初始化成功');
        console.log(`   钱包地址: ${this.wallet.address}`);
        console.log(`   Core Bridge: ${CONFIG.coreBridgeAddress}`);
        console.log(`   Token Bridge: ${CONFIG.tokenBridgeAddress}`);
        console.log(`   提交模式: ${CONFIG.submitToChain ? '启用' : '禁用（仅验证）'}`);
    }
    
    async fetchVAA(chainId, emitterAddress, sequence) {
        const url = `${CONFIG.guardianRestApi}/v1/signed_vaa/${chainId}/${emitterAddress}/${sequence}`;
        
        try {
            const response = await fetch(url);
            if (!response.ok) {
                if (response.status === 404) {
                    return null;
                }
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            const data = await response.json();
            if (!data.vaaBytes) {
                return null;
            }
            
            return Buffer.from(data.vaaBytes, 'base64');
        } catch (error) {
            if (error.code === 'ECONNREFUSED') {
                console.error('❌ 无法连接到Guardian REST API');
                return null;
            }
            throw error;
        }
    }
    
    async verifyVAA(vaaBytes) {
        try {
            const result = await this.coreBridge.parseAndVerifyVM(vaaBytes);
            return {
                vm: result[0],
                valid: result[1],
                reason: result[2]
            };
        } catch (error) {
            console.error(`   ❌ VAA验证失败: ${error.message}`);
            return null;
        }
    }
    
    async processVAA(vaaBytes, sequence) {
        try {
            console.log(`   🔍 验证VAA...`);
            
            const verifyResult = await this.verifyVAA(vaaBytes);
            if (!verifyResult || !verifyResult.valid) {
                console.log(`   ⏭️  VAA验证失败，跳过sequence ${sequence}`);
                if (verifyResult && verifyResult.reason) {
                    console.log(`      失败原因: ${verifyResult.reason}`);
                }
                return false;
            }
            
            const vm = verifyResult.vm;
            console.log(`   ✅ VAA验证成功!`);
            console.log(`      Emitter Chain: ${vm.emitterChainId}`);
            console.log(`      Emitter Address: ${vm.emitterAddress}`);
            console.log(`      Sequence: ${vm.sequence.toString()}`);
            console.log(`      Timestamp: ${vm.timestamp}`);
            console.log(`      Consistency Level: ${vm.consistencyLevel}`);
            console.log(`      Payload Length: ${vm.payload.length} bytes`);
            console.log(`      Signatures: ${vm.signatures.length}`);
            
            // 尝试解码payload
            try {
                const payloadStr = ethers.utils.toUtf8String(vm.payload);
                console.log(`      Payload: ${payloadStr}`);
            } catch {
                console.log(`      Payload (hex): 0x${vm.payload.toString('hex').substring(0, 64)}...`);
            }
            
            console.log('');
            console.log('   🎉 Relayer成功接收并验证Guardian准备好的VAA!');
            
            // 如果启用了提交模式，尝试提交到链上
            if (CONFIG.submitToChain) {
                await this.submitToChain(vaaBytes, vm);
            }
            
            return true;
        } catch (error) {
            console.error(`   ❌ 处理VAA失败: ${error.message}`);
            return false;
        }
    }
    
    async submitToChain(vaaBytes, vm) {
        try {
            console.log('');
            console.log('   🚀 准备提交VAA到链上合约...');
            
            // 检查payload类型，判断使用哪个合约方法
            const payloadType = vm.payload[0];
            
            if (payloadType === 1) {
                // Token Bridge Transfer
                console.log('      检测到Token Transfer消息');
                console.log('      调用Token Bridge.completeTransfer()...');
                
                const tx = await this.tokenBridge.completeTransfer(vaaBytes, {
                    gasLimit: 500000,
                });
                
                console.log(`      ⏳ 等待交易确认... tx: ${tx.hash}`);
                const receipt = await tx.wait();
                
                console.log(`      ✅ VAA已成功提交到链上合约!`);
                console.log(`         Transaction: ${receipt.transactionHash}`);
                console.log(`         Gas Used: ${receipt.gasUsed.toString()}`);
                console.log(`         Status: ${receipt.status === 1 ? '成功' : '失败'}`);
                
            } else {
                console.log(`      ⚠️  未知的payload类型: ${payloadType}`);
                console.log('      跳过提交（这是普通消息，不是Token Transfer）');
            }
            
        } catch (error) {
            if (error.message && error.message.includes('transfer already completed')) {
                console.log(`      ℹ️  VAA已经被处理过了`);
            } else {
                console.error(`      ❌ 提交失败: ${error.message}`);
            }
        }
    }
    
    async pollForNewVAAs() {
        const startSeq = this.latestSequence + 1;
        const endSeq = startSeq + 5;
        
        for (let seq = startSeq; seq < endSeq; seq++) {
            if (this.processedSequences.has(seq)) {
                continue;
            }
            
            console.log(`🔍 检查Sequence ${seq}...`);
            
            const vaaBytes = await this.fetchVAA(
                CONFIG.chainId,
                CONFIG.emitterAddress,
                seq
            );
            
            if (!vaaBytes) {
                break;
            }
            
            console.log(`   ✅ 获取到VAA (${vaaBytes.length} bytes)`);
            
            const success = await this.processVAA(vaaBytes, seq);
            
            if (success) {
                this.processedSequences.add(seq);
                this.latestSequence = Math.max(this.latestSequence, seq);
            }
        }
    }
    
    async start() {
        console.log('');
        console.log('🚀 Relayer启动中...');
        console.log(`   轮询间隔: ${CONFIG.pollInterval}ms`);
        console.log('');
        
        const balance = await this.wallet.getBalance();
        console.log(`💰 钱包余额: ${ethers.utils.formatEther(balance)} ETH`);
        console.log('');
        
        console.log('👂 开始监听新的VAA...');
        console.log('   (按 Ctrl+C 停止)');
        console.log('');
        
        // 立即执行一次
        try {
            await this.pollForNewVAAs();
        } catch (error) {
            console.error('❌ 初次轮询出错:', error.message);
        }
        
        // 定时轮询
        setInterval(async () => {
            try {
                await this.pollForNewVAAs();
            } catch (error) {
                console.error('❌ 轮询出错:', error.message);
            }
        }, CONFIG.pollInterval);
    }
}

async function main() {
    console.log('='.repeat(60));
    console.log('      Relayer - 监听Guardian VAA并提交到链上');
    console.log('='.repeat(60));
    
    const relayer = new RelayerWithSubmit();
    await relayer.start();
}

process.on('SIGINT', () => {
    console.log('\n\n👋 Relayer已停止');
    process.exit(0);
});

process.on('unhandledRejection', (error) => {
    console.error('未处理的Promise拒绝:', error);
});

main().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
});

