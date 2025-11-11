#!/usr/bin/env node
/**
 * transfer-usdc-arb-to-1024.js
 * 从 Arbitrum Sepolia 发起 USDC 跨链到 1024Chain
 */

const { ethers } = require('ethers');

// 配置
const CONFIG = {
    arbitrum: {
        rpc: 'https://sepolia-rollup.arbitrum.io/rpc',
        tokenBridge: '0xC7A204bDBFe983FCD8d8E61D02b475D4073fF97e',  // Arbitrum testnet Token Bridge
        coreBridge: '0x6b9C8671cdDC8dEab9c719bB87cBd3e782bA6a35',     // Arbitrum Sepolia Core
        usdc: '0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d',        // Arbitrum Sepolia USDC
    },
    
    chain1024: {
        recipient: 'Bya3mRSGUzTG5qCkzmQhmXQu8bpQbpW3FjbSDpByHFce',
        wormholeChainId: 1,  // Solana/1024Chain Chain ID (目标链)
    },
    
    // Wormhole Chain IDs
    arbitrumSepoliaChainId: 10003,  // Arbitrum Sepolia 的 Wormhole Chain ID
    
    amount: '1000000',  // 1 USDC (6 decimals)
    privateKey: process.env.ARB_PRIVATE_KEY || 'b0097d4ceabfa835a37edfbe30c82cdf22867b1432c42f59e5e3715ec3f68d24',
};

// Token Bridge ABI (只包含需要的函数)
const TOKEN_BRIDGE_ABI = [
    'function transferTokens(address token, uint256 amount, uint16 recipientChain, bytes32 recipient, uint256 arbiterFee, uint32 nonce) public payable returns (uint64 sequence)',
];

// ERC20 ABI
const ERC20_ABI = [
    'function balanceOf(address) view returns (uint256)',
    'function decimals() view returns (uint8)',
    'function approve(address spender, uint256 amount) public returns (bool)',
    'function allowance(address owner, address spender) view returns (uint256)',
];

// 将 Solana 地址转换为 bytes32
function solanaAddressToBytes32(address) {
    const bs58 = require('bs58');
    const decoded = bs58.default ? bs58.default.decode(address) : bs58.decode(address);
    
    // Solana 地址是 32 bytes，直接转换
    const hex = '0x' + Buffer.from(decoded).toString('hex');
    return hex;
}

async function main() {
    console.log('========================================');
    console.log('  USDC 跨链转账');
    console.log('  Arbitrum Sepolia → 1024Chain');
    console.log('========================================\n');
    
    // 连接到 Arbitrum Sepolia
    const provider = new ethers.providers.JsonRpcProvider(CONFIG.arbitrum.rpc);
    const wallet = new ethers.Wallet(CONFIG.privateKey, provider);
    
    console.log('发送者地址:', wallet.address);
    
    // 检查 ETH 余额
    const balance = await provider.getBalance(wallet.address);
    console.log('ETH 余额:', ethers.utils.formatEther(balance), 'ETH');
    
    if (balance.lt(ethers.utils.parseEther('0.01'))) {
        console.warn('⚠️  ETH 余额较低，可能不足以支付 gas');
    }
    
    // 检查 USDC 余额
    const usdcContract = new ethers.Contract(CONFIG.arbitrum.usdc, ERC20_ABI, wallet);
    
    const usdcBalance = await usdcContract.balanceOf(wallet.address);
    const decimals = await usdcContract.decimals();
    console.log('USDC 余额:', ethers.utils.formatUnits(usdcBalance, decimals), 'USDC');
    
    if (usdcBalance.lt(CONFIG.amount)) {
        console.error('\n❌ USDC 余额不足');
        console.error('   需要:', ethers.utils.formatUnits(CONFIG.amount, decimals), 'USDC');
        console.error('   当前:', ethers.utils.formatUnits(usdcBalance, decimals), 'USDC');
        console.error('\n💡 获取测试 USDC:');
        console.error('   1. 访问 Arbitrum Sepolia Faucet');
        console.error('   2. 或使用 Aave Faucet: https://staging.aave.com/faucet/');
        process.exit(1);
    }
    
    console.log('');
    console.log('转账配置:');
    console.log('  Token:', CONFIG.arbitrum.usdc);
    console.log('  Amount:', ethers.utils.formatUnits(CONFIG.amount, decimals), 'USDC');
    console.log('  From Chain: Arbitrum Sepolia');
    console.log('  To Chain: 1024Chain (Wormhole Chain ID:', CONFIG.chain1024.wormholeChainId, ')');
    console.log('  Recipient:', CONFIG.chain1024.recipient);
    console.log('  Token Bridge:', CONFIG.arbitrum.tokenBridge);
    console.log('');
    
    try {
        // 步骤 1: 检查并批准 Token Bridge 花费 USDC
        console.log('步骤 1: 检查 Token Bridge 授权额度...');
        const allowance = await usdcContract.allowance(wallet.address, CONFIG.arbitrum.tokenBridge);
        
        if (allowance.lt(CONFIG.amount)) {
            console.log('  需要批准 Token Bridge 花费 USDC');
            const approveTx = await usdcContract.approve(CONFIG.arbitrum.tokenBridge, CONFIG.amount);
            console.log('  等待批准交易确认...');
            const approveReceipt = await approveTx.wait();
            console.log('  ✓ 批准交易已确认');
            console.log('  交易哈希:', approveReceipt.transactionHash);
        } else {
            console.log('  ✓ 已有足够的授权额度');
        }
        console.log('');
        
        // 步骤 2: 发起跨链转账
        console.log('步骤 2: 发起跨链转账...');
        
        // 将接收地址转换为 bytes32
        const recipientBytes32 = solanaAddressToBytes32(CONFIG.chain1024.recipient);
        console.log('  Recipient (bytes32):', recipientBytes32);
        
        // 创建随机 nonce
        const nonce = Math.floor(Math.random() * 1000000);
        
        // 连接 Token Bridge 合约
        const tokenBridge = new ethers.Contract(
            CONFIG.arbitrum.tokenBridge,
            TOKEN_BRIDGE_ABI,
            wallet
        );
        
        console.log('  发送交易...');
        const transferTx = await tokenBridge.transferTokens(
            CONFIG.arbitrum.usdc,
            CONFIG.amount,
            CONFIG.chain1024.wormholeChainId,
            recipientBytes32,
            0,  // arbiterFee
            nonce
        );
        
        console.log('  等待交易确认...');
        const receipt = await transferTx.wait();
        
        console.log('  ✓ 转账交易已确认');
        console.log('  交易哈希:', receipt.transactionHash);
        console.log('  区块号:', receipt.blockNumber);
        console.log('  Gas 使用:', receipt.gasUsed.toString());
        console.log('');
        
        // 从事件中解析 sequence
        console.log('消息信息:');
        const logMessageEvent = receipt.logs.find(
            log => log.address.toLowerCase() === CONFIG.arbitrum.coreBridge.toLowerCase()
        );
        
        if (logMessageEvent && logMessageEvent.topics.length > 2) {
            const sequence = ethers.BigNumber.from(logMessageEvent.topics[2]).toString();
            console.log('  Sequence:', sequence);
        }
        console.log('');
        
        console.log('========================================');
        console.log('  ✅ 跨链转账已发起！');
        console.log('========================================\n');
        
        console.log('接下来的步骤:');
        console.log('1. Guardian 将观察到这笔交易');
        console.log('2. 监控 Guardian 日志:');
        console.log('   tail -f /tmp/guardian.log | grep -i "' + receipt.transactionHash.slice(0, 10) + '"');
        console.log('   tail -f /tmp/guardian.log | grep -i "payload\\|observation"');
        console.log('');
        console.log('3. 检查两个 Guardian 是否捕获相同的 payload:');
        console.log('   tail -f /tmp/guardian.log | grep -A 5 "observation"');
        console.log('   tail -f /tmp/guardian-2.log | grep -A 5 "observation"');
        console.log('');
        console.log('4. 浏览器查看交易:');
        console.log('   https://sepolia.arbiscan.io/tx/' + receipt.transactionHash);
        console.log('');
        console.log('5. 等待约 1-2 分钟后检查 Guardian 是否捕获消息');
        console.log('');
        
    } catch (error) {
        console.error('\n❌ 转账失败:', error.message);
        if (error.transaction) {
            console.error('\n交易详情:', error.transaction);
        }
        if (error.reason) {
            console.error('失败原因:', error.reason);
        }
        process.exit(1);
    }
}

// 运行主函数
main()
    .then(() => {
        console.log('脚本执行完成');
        process.exit(0);
    })
    .catch((error) => {
        console.error('\n执行出错:', error);
        process.exit(1);
    });

