# 1024Chain USDC 跨链桥 - 快速开始

> **30分钟完成部署**

## 📦 你需要准备

1. **1024Chain RPC URL** - 你的节点地址
2. **USDC Mint 地址** - USDC 代币的 Mint（不是你的 Token Account！）
3. **部署钱包** - 至少 10 SOL 用于部署合约

⚠️ **重要**：只需要在 **1024Chain** 上部署合约，Arbitrum Sepolia 端可以使用 Wormhole 官方部署的合约。

## 🚀 最简单方式：一键部署

### 使用自动化脚本（推荐）⭐

```bash
# 1. 运行脚本
./deploy-1024chain.sh

# 2. 按提示充值钱包（如果余额不足 5 SOL）

# 3. 等待部署完成（约 5-10 分钟）

# 4. 记录输出的合约地址
```

脚本会自动完成所有部署步骤！

---

## 📋 手动部署（7步详细流程）

### 1️⃣ 准备钱包

```bash
cd /workspace/wormhole/solana

# 创建钱包
solana-keygen new -o payer-fogo-testnet.json --no-bip39-passphrase

# 查看地址
solana-keygen pubkey payer-fogo-testnet.json

# 向这个地址充值至少 10 SOL
```

### 2️⃣ 生成程序地址

```bash
# 为 Bridge 生成地址
solana-keygen new -o bridge-keypair.json --no-bip39-passphrase
BRIDGE_ADDRESS=$(solana-keygen pubkey bridge-keypair.json)

# 为 Token Bridge 生成地址
solana-keygen new -o token-bridge-keypair.json --no-bip39-passphrase
TOKEN_BRIDGE_ADDRESS=$(solana-keygen pubkey token-bridge-keypair.json)

echo "Bridge: $BRIDGE_ADDRESS"
echo "Token Bridge: $TOKEN_BRIDGE_ADDRESS"
```

### 3️⃣ 更新 Makefile

```bash
DEPLOYER_PUBKEY=$(solana-keygen pubkey payer-fogo-testnet.json)

sed -i "s/bridge_ADDRESS_fogo_testnet=.*/bridge_ADDRESS_fogo_testnet=$BRIDGE_ADDRESS/" Makefile
sed -i "s/token_bridge_ADDRESS_fogo_testnet=.*/token_bridge_ADDRESS_fogo_testnet=$TOKEN_BRIDGE_ADDRESS/" Makefile
sed -i "s/bridge_AUTHORITY_fogo_testnet=.*/bridge_AUTHORITY_fogo_testnet=$DEPLOYER_PUBKEY/" Makefile
sed -i "s/token_bridge_AUTHORITY_fogo_testnet=.*/token_bridge_AUTHORITY_fogo_testnet=$DEPLOYER_PUBKEY/" Makefile
```

### 4️⃣ 编译合约

```bash
make artifacts SVM=fogo NETWORK=testnet
```

### 5️⃣ 部署合约

```bash
RPC_URL="https://testnet-rpc.1024chain.com/rpc/"

# 部署 Bridge
solana program deploy \
    artifacts-fogo-testnet/bridge.so \
    --program-id bridge-keypair.json \
    --keypair payer-fogo-testnet.json \
    --url "$RPC_URL" \
    --with-compute-unit-price 1000 \
    --use-rpc

# 部署 Token Bridge
solana program deploy \
    artifacts-fogo-testnet/token_bridge.so \
    --program-id token-bridge-keypair.json \
    --keypair payer-fogo-testnet.json \
    --url "$RPC_URL" \
    --with-compute-unit-price 1000 \
    --use-rpc
```

### 6️⃣ 配置 Guardian

创建 `node/config/guardian.yaml`：

```yaml
network: testnet
unsafeDevMode: true

# 1024Chain 端（你部署的合约）
solana:
  rpc: "https://testnet-rpc.1024chain.com/rpc/"
  bridge: "你在步骤5部署的Bridge地址"
  tokenBridge: "你在步骤5部署的TokenBridge地址"
  commitment: "finalized"

# Arbitrum Sepolia 端（使用官方合约）
ethereum:
  - chainId: 421614
    rpc: "https://sepolia-rollup.arbitrum.io/rpc"
    bridge: "0x6b9C8671cdDC8dEab9c719bB87cBd3e782bA6a35"  # Wormhole 官方部署
    tokenBridge: "查询 Wormhole 官方文档获取地址"
```

💡 **说明**：Arbitrum Sepolia 使用 Wormhole 官方部署的合约，无需重新部署。

启动：

```bash
cd node
make build
./build/guardiand node --config config/guardian.yaml
```

### 7️⃣ 测试转账

使用 SDK：

```typescript
import { Bridge1024Chain } from './examples/1024chain-bridge/src/bridge';

const bridge = new Bridge1024Chain({
  chain1024: {
    rpcUrl: 'https://testnet-rpc.1024chain.com/rpc/',
    tokenBridgeAddress: '你部署的TokenBridge地址',
  },
  arbitrumSepolia: {
    rpcUrl: 'https://sepolia-rollup.arbitrum.io/rpc',
    tokenBridgeAddress: 'Arbitrum地址',
  },
});

// 测试：1024Chain → Arbitrum
await bridge.bridgeTokens({
  tokenAddress: '你的USDC_Mint地址',
  amount: '1000000',  // 1 USDC
  recipientAddress: '0x你的Arbitrum地址',
  senderKeyPair: yourKeypair,
  direction: '1024chain-to-arbitrum',
});
```

## ✅ 完成！

你的跨链桥已经部署完成。

## 📚 更多文档

- [完整文档](refactor-docs/README.md) - 详细说明
- [API 文档](refactor-docs/API-SPEC.md) - API 接口
- [项目进度](refactor-docs/PROGRESS.md) - 当前状态

## ❓ 常见问题

**Q: USDC 地址是什么？**  
A: 是 USDC 的 **Mint Address**（代币铸造地址），不是你的 Token Account。用 `spl-token accounts` 查看。

**Q: 部署失败怎么办？**  
A: 检查钱包余额、RPC 连接、合约编译是否正确。

**Q: 转账多久到账？**  
A: 通常 1-3 分钟，取决于 Guardian 确认速度。

---

*最后更新: 2025-11-10*

