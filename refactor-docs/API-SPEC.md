# 跨链桥 API 文档

## 目录

- [核心 API](#核心-api)
- [配置 API](#配置-api)
- [工具函数](#工具函数)
- [自定义代币映射](#自定义代币映射)
- [错误处理](#错误处理)

---

## 核心 API

### Bridge1024Chain 类

主要的跨链桥接口类。

#### 构造函数

```typescript
constructor(config?: Partial<BridgeConfig>)
```

**参数**：
```typescript
interface BridgeConfig {
  chain1024: {
    rpcUrl: string;
    bridgeAddress: string;
    tokenBridgeAddress: string;
    chainId: ChainId;
  };
  arbitrumSepolia: {
    rpcUrl: string;
    bridgeAddress: string;
    tokenBridgeAddress: string;
    chainId: ChainId;
  };
  wormhole: {
    rpcHosts: string[];
    restUrl: string;
  };
}
```

**示例**：
```typescript
const bridge = new Bridge1024Chain({
  chain1024: {
    rpcUrl: 'https://testnet-rpc.1024chain.io',
    bridgeAddress: 'BRIDGE_ADDRESS',
    tokenBridgeAddress: 'TOKEN_BRIDGE_ADDRESS',
  },
  arbitrumSepolia: {
    rpcUrl: 'https://sepolia-rollup.arbitrum.io/rpc',
    bridgeAddress: '0x6b9C8671cdDC8dEab9c719bB87cBd3e782bA6a35',
    tokenBridgeAddress: 'TOKEN_BRIDGE_ADDRESS',
  },
});
```

---

### transferFromChain1024()

从 1024Chain 发起跨链转账。

```typescript
async transferFromChain1024(options: TransferOptions): Promise<TransferResult>
```

**参数**：
```typescript
interface TransferOptions {
  tokenAddress: string;        // SPL Token Mint 地址（不是个人 Token Account）
  amount: string;               // 转账数量（最小单位）
  recipientAddress: string;     // 目标链接收地址（0x...）
  senderKeyPair: Keypair;       // 发送者密钥对
}
```

**返回值**：
```typescript
interface TransferResult {
  txHash: string;           // 交易哈希
  sequence: string;         // VAA 序列号
  emitterAddress: string;   // 发射器地址
}
```

**示例**：
```typescript
const result = await bridge.transferFromChain1024({
  tokenAddress: '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',  // USDC Mint Address
  amount: '1000000',  // 1 USDC (6 decimals)
  recipientAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb7',
  senderKeyPair: keypair,
});

console.log('TX Hash:', result.txHash);
console.log('Sequence:', result.sequence);
```

**错误码**：
- `INSUFFICIENT_BALANCE` - 余额不足
- `TOKEN_NOT_FOUND` - 代币不存在
- `INVALID_RECIPIENT` - 接收地址无效
- `TRANSACTION_FAILED` - 交易失败

---

### transferFromArbitrum()

从 Arbitrum Sepolia 发起跨链转账。

```typescript
async transferFromArbitrum(options: TransferOptions): Promise<TransferResult>
```

**参数**：
```typescript
interface TransferOptions {
  tokenAddress: string;        // ERC20 代币地址
  amount: string;               // 转账数量（最小单位）
  recipientAddress: string;     // 1024Chain 接收地址（Base58）
  senderPrivateKey: string;     // 发送者私钥
}
```

**返回值**：同 `transferFromChain1024()`

**示例**：
```typescript
const result = await bridge.transferFromArbitrum({
  tokenAddress: '0x...',
  amount: '1000000000000000000',  // 1 token (18 decimals)
  recipientAddress: '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
  senderPrivateKey: '0x...',
});
```

---

### getSignedVAA()

获取已签名的 VAA。

```typescript
async getSignedVAA(
  sequence: string,
  emitterAddress: string,
  chainId?: number
): Promise<Uint8Array>
```

**参数**：
- `sequence` - VAA 序列号（从 TransferResult 获取）
- `emitterAddress` - 发射器地址（从 TransferResult 获取）
- `chainId` - 源链 ID（默认：1024Chain）

**返回值**：
- `Uint8Array` - 已签名的 VAA 字节

**示例**：
```typescript
const vaa = await bridge.getSignedVAA(
  result.sequence,
  result.emitterAddress
);
```

**说明**：
- 通常需要等待 15-60 秒才能获取到 VAA
- 会自动重试直到超时（默认 5 分钟）

---

### redeemOnArbitrum()

在 Arbitrum 上赎回代币。

```typescript
async redeemOnArbitrum(
  vaaBytes: Uint8Array,
  recipientPrivateKey: string
): Promise<string>
```

**参数**：
- `vaaBytes` - 已签名的 VAA（从 getSignedVAA 获取）
- `recipientPrivateKey` - 接收者私钥（支付 Gas）

**返回值**：
- `string` - 赎回交易哈希

**示例**：
```typescript
const redeemTx = await bridge.redeemOnArbitrum(
  vaa,
  '0xPRIVATE_KEY'
);
console.log('Redeemed:', redeemTx);
```

---

### redeemOnChain1024()

在 1024Chain 上赎回代币。

```typescript
async redeemOnChain1024(
  vaaBytes: Uint8Array,
  recipientKeyPair: Keypair
): Promise<string>
```

**参数**：
- `vaaBytes` - 已签名的 VAA
- `recipientKeyPair` - 接收者密钥对

**返回值**：
- `string` - 赎回交易签名

---

### bridgeTokens()

完整的跨链转账流程（自动处理 VAA）。

```typescript
async bridgeTokens(
  options: TransferOptions & { 
    direction: '1024chain-to-arbitrum' | 'arbitrum-to-1024chain' 
  }
): Promise<{ sourceTx: string; redeemTx: string }>
```

**参数**：
- 继承 `TransferOptions`
- `direction` - 转账方向

**返回值**：
```typescript
{
  sourceTx: string;    // 源链交易哈希
  redeemTx: string;    // 目标链赎回交易哈希
}
```

**示例**：
```typescript
const result = await bridge.bridgeTokens({
  tokenAddress: 'TOKEN_ADDRESS',
  amount: '1000000',
  recipientAddress: '0x...',
  senderKeyPair: keypair,
  senderPrivateKey: '0x...',
  direction: '1024chain-to-arbitrum',
});

console.log('Source TX:', result.sourceTx);
console.log('Redeem TX:', result.redeemTx);
```

**说明**：
- 自动等待 VAA 生成
- 自动在目标链赎回
- 整个过程约 1-3 分钟

---

### getStatus()

获取连接状态。

```typescript
async getStatus(): Promise<{
  chain1024: { connected: boolean; slot?: number };
  arbitrum: { connected: boolean; blockNumber?: number };
}>
```

**示例**：
```typescript
const status = await bridge.getStatus();
console.log('1024Chain:', status.chain1024);
console.log('Arbitrum:', status.arbitrum);
```

---

## 配置 API

### loadConfig()

从环境变量加载配置。

```typescript
function loadConfig(): BridgeConfig
```

**环境变量示例**：
```bash
# 示例配置（请替换为实际值）
CHAIN_1024_RPC_URL=your_1024chain_rpc_url
CHAIN_1024_BRIDGE_ADDRESS=your_bridge_address
CHAIN_1024_TOKEN_BRIDGE_ADDRESS=your_token_bridge_address

ARBITRUM_SEPOLIA_RPC_URL=your_arbitrum_rpc_url
ARBITRUM_SEPOLIA_BRIDGE_ADDRESS=your_bridge_address
ARBITRUM_SEPOLIA_TOKEN_BRIDGE_ADDRESS=your_token_bridge_address

WORMHOLE_RPC_HOST=wormhole_api_endpoint
```

⚠️ **注意**：上述为配置格式示例，请勿直接使用

---

### validateConfig()

验证配置完整性。

```typescript
function validateConfig(config: BridgeConfig): void
```

**示例**：
```typescript
const config = loadConfig();
validateConfig(config);  // 抛出错误如果配置无效
```

---

## 工具函数

### parseSequenceFromLogSolana()

从 Solana 交易日志解析序列号。

```typescript
function parseSequenceFromLogSolana(tx: TransactionResponse): string
```

### parseSequenceFromLogEth()

从 Ethereum 交易日志解析序列号。

```typescript
function parseSequenceFromLogEth(
  receipt: TransactionReceipt,
  bridgeAddress: string
): string
```

### getEmitterAddressSolana()

获取 Solana Token Bridge 的发射器地址。

```typescript
async function getEmitterAddressSolana(
  tokenBridgeAddress: string
): Promise<string>
```

---

## 自定义代币映射

### 方法1: Bridge + DEX 自动兑换

质押代币 A，在目标链获得代币 B。

```typescript
class CustomBridgeSwap extends Bridge1024Chain {
  async stakeAndReceiveDifferentToken(options: {
    sourceToken: string;      // 1024Chain 上的代币 A
    targetToken: string;      // Arbitrum 上的代币 B
    amount: string;
    recipientAddress: string;
    senderKeyPair: Keypair;
  }): Promise<{
    sourceTx: string;
    redeemTx: string;
    sourceToken: string;
    targetToken: string;
  }>
}
```

**示例**：
```typescript
const customBridge = new CustomBridgeSwap(SWAP_CONTRACT_ADDRESS);

// 质押 USDC，获得 DAI
const result = await customBridge.stakeAndReceiveDifferentToken({
  sourceToken: '1024CHAIN_USDC',
  targetToken: 'ARBITRUM_DAI',
  amount: '1000000',
  recipientAddress: '0x...',
  senderKeyPair: keypair,
});
```

**工作流程**：
1. 用户在 1024Chain 锁定代币 A
2. Wormhole 跨链，在 Arbitrum 铸造 Wrapped 代币 A
3. SwapContract 自动在 Uniswap 将 Wrapped A 兑换为代币 B
4. 用户收到代币 B

**部署 SwapContract**：
```solidity
contract SwapReceiver {
    mapping(address => address) public tokenMapping;
    
    function setTokenMapping(
        address wrappedToken,
        address targetToken
    ) external onlyOwner;
    
    function onTokenReceived(
        address wrappedToken,
        uint256 amount,
        address recipient
    ) external;
}
```

---

## 错误处理

### 错误类型

```typescript
enum BridgeError {
  // 配置错误
  INVALID_CONFIG = 'INVALID_CONFIG',
  MISSING_PRIVATE_KEY = 'MISSING_PRIVATE_KEY',
  
  // 余额错误
  INSUFFICIENT_BALANCE = 'INSUFFICIENT_BALANCE',
  INSUFFICIENT_GAS = 'INSUFFICIENT_GAS',
  
  // 代币错误
  TOKEN_NOT_FOUND = 'TOKEN_NOT_FOUND',
  TOKEN_NOT_REGISTERED = 'TOKEN_NOT_REGISTERED',
  
  // 交易错误
  TRANSACTION_FAILED = 'TRANSACTION_FAILED',
  INVALID_RECIPIENT = 'INVALID_RECIPIENT',
  
  // VAA 错误
  VAA_NOT_FOUND = 'VAA_NOT_FOUND',
  VAA_TIMEOUT = 'VAA_TIMEOUT',
  VAA_ALREADY_EXECUTED = 'VAA_ALREADY_EXECUTED',
  
  // 网络错误
  RPC_ERROR = 'RPC_ERROR',
  NETWORK_ERROR = 'NETWORK_ERROR',
}
```

### 错误处理示例

```typescript
try {
  const result = await bridge.bridgeTokens({...});
} catch (error) {
  if (error.code === BridgeError.INSUFFICIENT_BALANCE) {
    console.error('余额不足');
  } else if (error.code === BridgeError.VAA_TIMEOUT) {
    console.error('VAA 获取超时，请稍后重试');
  } else {
    console.error('未知错误:', error);
  }
}
```

### 重试机制

```typescript
async function bridgeWithRetry(
  options: TransferOptions,
  maxRetries: number = 3
): Promise<TransferResult> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await bridge.bridgeTokens(options);
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      await sleep(5000);  // 等待 5 秒后重试
    }
  }
}
```

---

## 事件监听

### 监听转账事件

```typescript
bridge.on('transfer', (event) => {
  console.log('Transfer initiated:', event);
});

bridge.on('vaa-generated', (event) => {
  console.log('VAA generated:', event);
});

bridge.on('redeemed', (event) => {
  console.log('Tokens redeemed:', event);
});
```

---

## 性能优化

### 批量转账

```typescript
async function batchTransfer(transfers: TransferOptions[]): Promise<TransferResult[]> {
  const promises = transfers.map(t => bridge.transferFromChain1024(t));
  return await Promise.all(promises);
}
```

### 缓存 VAA

```typescript
const vaaCache = new Map<string, Uint8Array>();

async function getCachedVAA(sequence: string, emitter: string): Promise<Uint8Array> {
  const key = `${sequence}-${emitter}`;
  if (vaaCache.has(key)) {
    return vaaCache.get(key)!;
  }
  const vaa = await bridge.getSignedVAA(sequence, emitter);
  vaaCache.set(key, vaa);
  return vaa;
}
```

---

## Guardian 管理 API

### Guardian 节点管理

Guardian 节点是 Wormhole 跨链桥的核心组件，负责监听链上事件、验证消息并生成 VAA。

#### 启动 Guardian

```bash
# 启动 Guardian 1 (主节点)
bash scripts/1024chain/start-guardian-final.sh

# 启动 Guardian 2 (备用节点)
bash scripts/1024chain/start-guardian-2.sh
```

#### 查看 Guardian 状态

```bash
# 查看所有 Guardian 的运行状态
bash scripts/1024chain/guardian-status.sh
```

**输出示例：**
```
【Guardian 1】
  状态: ✅ 运行中 (PID: 1173310)
  地址: 0x76c58bA8559589BA3990Ce0A1efcd7039561F530
  端口: 6060 (status), 8999 (p2p)
  健康: ✅ 正常

【Guardian 2】
  状态: ✅ 运行中 (PID: 1174605)
  地址: 0x76dFa2Ff0941bbaa0982A2177e8a68F4B510285A
  端口: 6061 (status), 9000 (p2p)
  健康: ✅ 正常
```

#### Guardian Admin 命令

**查看配置的 RPC：**
```bash
guardiand admin dump-rpcs --socket /tmp/sockets/admin.sock
```

**发送观察请求：**
```bash
guardiand admin send-observation-request \
  --socket /tmp/sockets/admin.sock \
  <chain_id> \
  <transaction_hash>

# 示例：观察 Arbitrum Sepolia 上的交易
guardiand admin send-observation-request \
  --socket /tmp/sockets/admin.sock \
  10003 \
  0x5313d3a505999cf0badff1404262fda25341f2d16d3814c108bba8c5c7683c91
```

**查看节点列表：**
```bash
guardiand admin list-nodes \
  --socket /tmp/sockets/admin.sock \
  --showDetails
```

**查询 VAA：**
```bash
guardiand admin dump-vaa-by-message-id \
  --socket /tmp/sockets/admin.sock \
  <chain_id>/<emitter_address>/<sequence>

# 示例：查询 Arbitrum Sepolia 的 VAA
guardiand admin dump-vaa-by-message-id \
  --socket /tmp/sockets/admin.sock \
  10003/0x539ADcac182c2Ec8f625c55ae6b048fE8Ce7a3E5/1
```

#### Guardian 健康检查 API

**端点：** `http://localhost:6060/readyz`

**响应格式：**
```
[not suitable for monitoring - do not parse]

ethSyncing: false
solanaSyncing: true
arbitrum_sepoliaSyncing: false
```

**Metrics 端点：** `http://localhost:6060/metrics`

关键指标：
- `wormhole_guardian_observations_total` - 观察到的消息总数
- `wormhole_p2p_broadcast_messages_received_total` - P2P 消息接收数
- `wormhole_eth_connection_errors_count` - EVM 连接错误数

#### Wormhole Chain ID 映射

| 区块链 | EVM Chain ID | Wormhole Chain ID |
|--------|-------------|-------------------|
| Solana / 1024Chain | N/A | 1 |
| Ethereum Sepolia | 11155111 | 10002 |
| Arbitrum Sepolia | 421614 | **10003** |
| Base Sepolia | 84532 | 10004 |
| Optimism Sepolia | 11155420 | 10005 |

⚠️ **重要**：在使用 Guardian admin 命令时，必须使用 **Wormhole Chain ID**，而不是 EVM Chain ID。

---

## 命令行工具

### transfer-to-arbitrum

```bash
npm run transfer:to-arbitrum -- \
  --token <代币地址> \
  --amount <数量> \
  --recipient <接收地址> \
  --keypair <密钥文件路径>
```

### check-status

```bash
npm run check-status -- \
  --sequence <序列号> \
  --emitter <发射器地址>
```

---

*最后更新: 2025-11-10*

