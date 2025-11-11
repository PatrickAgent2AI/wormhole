#!/usr/bin/env node

/**
 * 简单的本地Relayer
 * 功能：
 * 1. 从Guardian REST API获取VAA
 * 2. 将VAA提交到本地Anvil链（模拟1024chain）
 */

const ethers = require('ethers');
const fs = require('fs');
const path = require('path');

// 配置
const CONFIG = {
    guardianRestApi: process.env.GUARDIAN_REST_API || 'http://localhost:7071',
    rpcUrl: process.env.RPC_URL || 'http://localhost:8545',
    coreBridgeAddress: process.env.CORE_BRIDGE || '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
    tokenBridgeAddress: process.env.TOKEN_BRIDGE || '0x0165878A594ca255338adfa4d48449f69242Eb8F',
    chainId: 2, // Anvil链ID（模拟以太坊）
    emitterAddress: '000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266', // Anvil测试账户
    pollInterval: 5000, // 5秒轮询一次
};

// Core Bridge ABI（只包含我们需要的函数）
const CORE_BRIDGE_ABI = [
    'function parseAndVerifyVM(bytes calldata encodedVM) external view returns (tuple(uint8 version, uint32 timestamp, uint32 nonce, uint16 emitterChainId, bytes32 emitterAddress, uint64 sequence, uint8 consistencyLevel, bytes payload, uint32 guardianSetIndex, tuple(bytes32 r, bytes32 s, uint8 v, uint8 guardianIndex)[] signatures, bytes32 hash) vm, bool valid, string memory reason)',
    'event LogMessagePublished(address indexed sender, uint64 sequence, uint32 nonce, bytes payload, uint8 consistencyLevel)',
];

// Token Bridge ABI
const TOKEN_BRIDGE_ABI = [
    'function completeTransfer(bytes memory encodedVm) public',
    'function completeTransferWithPayload(bytes memory encodedVm) public returns (bytes memory)',
];

class SimpleRelayer {
    constructor() {
        this.provider = new ethers.providers.JsonRpcProvider(CONFIG.rpcUrl);
        this.processedSequences = new Set();
        this.latestSequence = -1;
        
        // 使用Anvil默认账户
        const privateKey = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
        this.wallet = new ethers.Wallet(privateKey, this.provider);
        
        this.coreBridge = new ethers.Contract(CONFIG.coreBridgeAddress, CORE_BRIDGE_ABI, this.wallet);
        this.tokenBridge = new ethers.Contract(CONFIG.tokenBridgeAddress, TOKEN_BRIDGE_ABI, this.wallet);
        
        console.log('✅ Relayer初始化成功');
        console.log(`   钱包地址: ${this.wallet.address}`);
        console.log(`   Core Bridge: ${CONFIG.coreBridgeAddress}`);
        console.log(`   Token Bridge: ${CONFIG.tokenBridgeAddress}`);
    }
    
    async getWalletBalance() {
        const balance = await this.wallet.getBalance();
        return ethers.utils.formatEther(balance);
    }
    
    // 从Guardian获取VAA
    async fetchVAA(chainId, emitterAddress, sequence) {
        const url = `${CONFIG.guardianRestApi}/v1/signed_vaa/${chainId}/${emitterAddress}/${sequence}`;
        
        try {
            const response = await fetch(url);
            if (!response.ok) {
                if (response.status === 404) {
                    return null; // VAA还未准备好
                }
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            const data = await response.json();
            if (!data.vaaBytes) {
                return null;
            }
            
            // vaaBytes是base64编码的
            const vaaBytes = Buffer.from(data.vaaBytes, 'base64');
            return vaaBytes;
        } catch (error) {
            if (error.code === 'ECONNREFUSED') {
                console.error('❌ 无法连接到Guardian REST API');
                return null;
            }
            throw error;
        }
    }
    
    // 验证VAA
    async verifyVAA(vaaBytes) {
        try {
            const result = await this.coreBridge.parseAndVerifyVM(vaaBytes);
            // result是一个包含[vm, valid, reason]的数组
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
    
    // 处理VAA（验证并显示信息）
    async processVAA(vaaBytes, sequence) {
        try {
            console.log(`   🔍 验证VAA...`);
            
            // 验证VAA
            const verifyResult = await this.verifyVAA(vaaBytes);
            if (!verifyResult || !verifyResult.valid) {
                console.log(`   ⏭️  VAA验证失败，跳过sequence ${sequence}`);
                return false;
            }
            
            // 显示VAA信息
            const vm = verifyResult.vm;
            console.log(`   ✅ VAA验证成功!`);
            console.log(`      Emitter Chain: ${vm.emitterChainId}`);
            console.log(`      Emitter Address: ${vm.emitterAddress}`);
            console.log(`      Sequence: ${vm.sequence.toString()}`);
            console.log(`      Timestamp: ${vm.timestamp}`);
            console.log(`      Nonce: ${vm.nonce}`);
            console.log(`      Consistency Level: ${vm.consistencyLevel}`);
            console.log(`      Payload Length: ${vm.payload.length} bytes`);
            console.log(`      Guardian Set Index: ${vm.guardianSetIndex}`);
            console.log(`      Signatures: ${vm.signatures.length}`);
            
            // 尝试解码payload（如果是UTF-8字符串）
            try {
                const payloadStr = ethers.utils.toUtf8String(vm.payload);
                console.log(`      Payload (UTF-8): ${payloadStr}`);
            } catch {
                console.log(`      Payload (hex): 0x${vm.payload.toString('hex').substring(0, 64)}...`);
            }
            
            console.log('');
            console.log('   🎉 Relayer成功接收并验证Guardian准备好的VAA!');
            
            return true;
        } catch (error) {
            console.error(`   ❌ 处理VAA失败: ${error.message}`);
            if (error.error) {
                console.error(`      详细错误: ${error.error.message || error.error}`);
            }
            return false;
        }
    }
    
    // 轮询新的VAA
    async pollForNewVAAs() {
        const startSeq = this.latestSequence + 1;
        const endSeq = startSeq + 5; // 每次检查5个sequence
        
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
                // VAA还未准备好，停止检查更高的sequence
                break;
            }
            
            console.log(`   ✅ 获取到VAA (${vaaBytes.length} bytes)`);
            
            // 处理VAA
            const success = await this.processVAA(vaaBytes, seq);
            
            if (success) {
                this.processedSequences.add(seq);
                this.latestSequence = Math.max(this.latestSequence, seq);
            }
        }
    }
    
    // 启动relayer
    async start() {
        console.log('');
        console.log('🚀 Relayer启动中...');
        console.log(`   轮询间隔: ${CONFIG.pollInterval}ms`);
        console.log('');
        
        // 检查钱包余额
        const balance = await this.getWalletBalance();
        console.log(`💰 钱包余额: ${balance} ETH`);
        console.log('');
        
        console.log('👂 开始监听新的VAA...');
        console.log('   (按 Ctrl+C 停止)');
        console.log('');
        
        // 定时轮询
        setInterval(async () => {
            try {
                await this.pollForNewVAAs();
            } catch (error) {
                console.error('❌ 轮询出错:', error.message);
            }
        }, CONFIG.pollInterval);
        
        // 立即执行一次
        try {
            await this.pollForNewVAAs();
        } catch (error) {
            console.error('❌ 初次轮询出错:', error.message);
        }
    }
}

// 主函数
async function main() {
    console.log('='.repeat(60));
    console.log('      简单本地Relayer - 监听Guardian VAA');
    console.log('='.repeat(60));
    
    const relayer = new SimpleRelayer();
    await relayer.start();
}

// 处理退出信号
process.on('SIGINT', () => {
    console.log('\n\n👋 Relayer已停止');
    process.exit(0);
});

// 错误处理
process.on('unhandledRejection', (error) => {
    console.error('未处理的Promise拒绝:', error);
});

// 运行
main().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
});

