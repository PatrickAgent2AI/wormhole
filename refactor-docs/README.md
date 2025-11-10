# 1024Chain 跨链桥项目文档

> 基于 Wormhole 协议实现 1024Chain 到 Arbitrum Sepolia 的跨链代币桥

**当前状态**: POC 阶段完成 ✅ | **最后更新**: 2025-11-10

---

## 📚 文档索引

### 核心文档（本目录下）

| 文档 | 说明 | 适用人群 | 文件大小 |
|------|------|---------|---------|
| **[README.md](README.md)** | 项目概述、目录结构、开发指南 | 所有人 | 5.2K |
| **[API-SPEC.md](API-SPEC.md)** | 完整的跨链桥 API 文档 | 开发者 | 12K |
| **[TEST-PLAN.md](TEST-PLAN.md)** | 测试用例、User Stories、测试计划 | 测试工程师 | 18K |
| **[PROGRESS.md](PROGRESS.md)** | 项目进度、里程碑、风险管理 | 项目经理 | 5.2K |

### 快速导航

- **🚀 快速开始** → 本文档「二次开发思路」章节
- **📖 API 使用** → [API-SPEC.md](API-SPEC.md) 「核心 API」章节
- **🧪 测试指南** → [TEST-PLAN.md](TEST-PLAN.md) 「User Stories」章节
- **📊 项目状态** → [PROGRESS.md](PROGRESS.md) 「当前状态」章节
- **⚙️ 自定义映射** → [API-SPEC.md](API-SPEC.md#自定义代币映射) 章节

---

## 📁 项目目录结构

### 一级目录说明

```
wormhole/
├── node/                    # Guardian 节点实现（Go）
│                            # - 跨链消息验证和签名
│                            # - 多链监听和事件处理
│
├── solana/                  # Solana/1024Chain 智能合约（Rust）
│                            # - Core Bridge 和 Token Bridge
│                            # - 合约部署和升级脚本
│
├── ethereum/                # EVM 链智能合约（Solidity）
│                            # - Arbitrum/EVM 桥接合约
│                            # - Foundry 测试和部署
│
├── sdk/                     # 跨链 SDK
│                            # - TypeScript/Python/Rust SDK
│                            # - VAA 生成和解析工具
│
├── proto/                   # Protocol Buffers 定义
│                            # - Chain ID 定义
│                            # - 跨链消息格式
│
├── scripts/                 # 辅助脚本
│   └── 1024chain/          # Guardian 部署和测试脚本
│       ├── start-guardian-final.sh    # 启动 Guardian 1
│       ├── start-guardian-2.sh        # 启动 Guardian 2
│       ├── guardian-status.sh         # 查看 Guardian 状态
│       ├── send-test-message.sh       # 发送测试消息
│       └── test-arbitrum-bridge.sh    # Token Bridge 测试
│
├── examples/                # 示例代码
│   └── 1024chain-bridge/   # 1024Chain 跨链桥 SDK
│       ├── src/            # TypeScript 源码
│       ├── scripts/        # 使用示例
│       └── package.json    # 依赖配置
│
└── refactor-docs/          # 📚 项目文档（本目录）
    ├── README.md           # 本文件 - 索引和开发指南
    ├── API-SPEC.md         # API 文档
    ├── TEST-PLAN.md        # 测试文档
    └── PROGRESS.md         # 项目进度
```

## 🎯 项目需求

基于 Wormhole 协议实现 1024Chain 到 Arbitrum Sepolia 测试网的 USDC 跨链桥。

**明确需求**：
1. ✅ 1024Chain ↔ Arbitrum Sepolia 跨链桥
2. ✅ 支持自定义 RPC 配置（必须）
3. ✅ 第一版仅支持 USDC 双向绑定
4. ✅ 多签钱包管理（Squads + Gnosis Safe）
5. ✅ 最小化修改：零代码改动，仅配置

**核心优势**：
- 🚀 **无需修改 Wormhole 代码** - 纯配置方案
- ⚡ **快速部署** - 1-2天完成
- 🔧 **灵活配置** - 自定义 RPC 和代币地址
- 🛡️ **多签安全** - Squads + Gnosis Safe 管理

## 🔧 实施方案：零代码改动

**核心思路**：
- 将 1024Chain 视为 Solana 的测试网络
- 使用现有 Solana 合约（无需修改）
- 仅配置不同的 RPC 端点

**为什么这样做**：
- ✅ **最简单** - 30分钟完成部署
- ✅ **零风险** - 使用成熟的 Wormhole 代码
- ✅ **易维护** - 不需要维护自定义代码

---

## ❓ 常见问题

### Q: Arbitrum Sepolia 端需要部署合约吗？

**测试阶段：不需要** ✅

Wormhole 已在 Arbitrum Sepolia 部署了官方合约，可以直接使用：
- **Core Bridge**: `0x6b9C8671cdDC8dEab9c719bB87cBd3e782bA6a35`
- **Token Bridge**: 查询 [Wormhole 官方文档](https://docs.wormhole.com/wormhole/reference/contracts)

**生产环境：可选**

如果需要完全独立的跨链桥系统，可以部署自己的合约。参见文档「第 6 步：Arbitrum Sepolia 端部署」。

---

## 🚀 最简单部署流程

### 方式 1：一键部署脚本（推荐）⭐

```bash
# 1. 运行自动部署脚本
./deploy-1024chain.sh

# 2. 按提示充值钱包（如果余额不足 5 SOL）

# 3. 等待部署完成（约 5-10 分钟）

# 4. 记录输出的合约地址
```

脚本会自动：
- ✅ 创建部署钱包
- ✅ 生成程序地址（bridge 和 token_bridge）
- ✅ 编译合约（使用正确的程序地址）
- ✅ 部署到 1024Chain
- ✅ 输出所有部署信息

---

### 方式 2：手动部署（详细步骤）

#### 第 1 步：准备环境

```bash
cd /workspace/wormhole/solana

# 1. 创建部署钱包
solana-keygen new -o payer-fogo-testnet.json --no-bip39-passphrase

# 2. 查看钱包地址
DEPLOYER_PUBKEY=$(solana-keygen pubkey payer-fogo-testnet.json)
echo "请向此地址充值至少 10 SOL: $DEPLOYER_PUBKEY"

# 3. 检查余额
solana balance payer-fogo-testnet.json \
    --url https://testnet-rpc.1024chain.com/rpc/
```

#### 第 2 步：生成程序地址

```bash
# 为 Bridge 生成固定地址
solana-keygen new -o bridge-keypair.json --no-bip39-passphrase
BRIDGE_ADDRESS=$(solana-keygen pubkey bridge-keypair.json)
echo "Bridge 程序地址: $BRIDGE_ADDRESS"

# 为 Token Bridge 生成固定地址
solana-keygen new -o token-bridge-keypair.json --no-bip39-passphrase
TOKEN_BRIDGE_ADDRESS=$(solana-keygen pubkey token-bridge-keypair.json)
echo "Token Bridge 程序地址: $TOKEN_BRIDGE_ADDRESS"
```

#### 第 3 步：更新 Makefile

```bash
# 更新程序地址到 Makefile（在编译前）
sed -i "s/bridge_ADDRESS_fogo_testnet=.*/bridge_ADDRESS_fogo_testnet=$BRIDGE_ADDRESS/" Makefile
sed -i "s/token_bridge_ADDRESS_fogo_testnet=.*/token_bridge_ADDRESS_fogo_testnet=$TOKEN_BRIDGE_ADDRESS/" Makefile
sed -i "s/bridge_AUTHORITY_fogo_testnet=.*/bridge_AUTHORITY_fogo_testnet=$DEPLOYER_PUBKEY/" Makefile
sed -i "s/token_bridge_AUTHORITY_fogo_testnet=.*/token_bridge_AUTHORITY_fogo_testnet=$DEPLOYER_PUBKEY/" Makefile
```

#### 第 4 步：编译合约

```bash
# 使用真实程序地址编译
make artifacts SVM=fogo NETWORK=testnet
```

#### 第 5 步：部署合约

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

echo "✓ Bridge 已部署到: $BRIDGE_ADDRESS"

# 部署 Token Bridge
solana program deploy \
    artifacts-fogo-testnet/token_bridge.so \
    --program-id token-bridge-keypair.json \
    --keypair payer-fogo-testnet.json \
    --url "$RPC_URL" \
    --with-compute-unit-price 1000 \
    --use-rpc

echo "✓ Token Bridge 已部署到: $TOKEN_BRIDGE_ADDRESS"
```

**关键参数说明**：
- `--use-rpc`: 强制使用 HTTP RPC（不使用 WebSocket）
- `--with-compute-unit-price`: 设置计算单元价格
- `--program-id`: 使用预先生成的程序地址

---

### 第 6 步：Arbitrum Sepolia 端部署

**选择 A：使用官方部署（推荐用于测试）✅**

Wormhole 已在 Arbitrum Sepolia 上部署了合约，可以直接使用：

```bash
# 查询官方合约地址
# Core Bridge: 0x6b9C8671cdDC8dEab9c719bB87cBd3e782bA6a35
# Token Bridge: 查询 https://docs.wormhole.com/wormhole/reference/contracts
```

**选择 B：部署独立合约（完全控制）🔧**

如果需要独立的跨链桥系统：

```bash
# 1. 准备 EVM 钱包（需要测试 ETH）
export ARBITRUM_PRIVATE_KEY="your_private_key"

# 2. 部署 Wormhole 合约到 Arbitrum Sepolia
cd ethereum
forge script script/DeployWormhole.s.sol \
    --rpc-url https://sepolia-rollup.arbitrum.io/rpc \
    --private-key $ARBITRUM_PRIVATE_KEY \
    --broadcast

# 3. 部署 Token Bridge
forge script script/DeployTokenBridge.s.sol \
    --rpc-url https://sepolia-rollup.arbitrum.io/rpc \
    --private-key $ARBITRUM_PRIVATE_KEY \
    --broadcast

# 记录部署的合约地址
```

⚠️ **注意**：部署到 Arbitrum Sepolia 需要测试 ETH 用于 Gas 费用。

---

### 第 7 步：配置并启动 Guardian

**Guardian** 是 Wormhole 的核心组件，负责监听链上事件、验证消息并生成 VAA（可验证操作批准）。

#### 快速启动（使用自动化脚本）✅

项目提供了完整的 Guardian 部署脚本，位于 `scripts/1024chain/`：

```bash
# 启动第一个 Guardian 节点
bash scripts/1024chain/start-guardian-final.sh

# （可选）启动第二个 Guardian 节点
bash scripts/1024chain/start-guardian-2.sh

# 查看 Guardian 状态
bash scripts/1024chain/guardian-status.sh
```

**已部署的 Guardian 节点：**
- Guardian 1: `0x76c58bA8559589BA3990Ce0A1efcd7039561F530` (端口 6060/8999)
- Guardian 2: `0x76dFa2Ff0941bbaa0982A2177e8a68F4B510285A` (端口 6061/9000)

#### 脚本功能说明

| 脚本 | 功能 | 用法 |
|------|------|------|
| `start-guardian-final.sh` | 启动 Guardian 1 | `bash scripts/1024chain/start-guardian-final.sh` |
| `start-guardian-2.sh` | 启动 Guardian 2 (多节点测试) | `bash scripts/1024chain/start-guardian-2.sh` |
| `guardian-status.sh` | 查看所有 Guardian 状态 | `bash scripts/1024chain/guardian-status.sh` |
| `send-test-message.sh` | 发送测试消息到链上 | `bash scripts/1024chain/send-test-message.sh <私钥>` |
| `test-arbitrum-bridge.sh` | 完整的 Token Bridge 测试 | `bash scripts/1024chain/test-arbitrum-bridge.sh` |

**配置说明：**

Guardian 自动连接到以下区块链：
- **1024Chain**: https://testnet-rpc.1024chain.com/rpc/ (合约: 2jBY6fEPcN5rhgMXzQgg5JQcsg8Sp38ud4F3N2vUyUsL)
- **Arbitrum Sepolia**: wss://arbitrum-sepolia.drpc.org (合约: 0x539ADcac182c2Ec8f625c55ae6b048fE8Ce7a3E5)
- **Ethereum Sepolia**: wss://ethereum-sepolia-rpc.publicnode.com (合约: 0x4a8bc80Ed5a4067f1CCf107057b8270E0cC11A78)

#### 手动配置（高级用法）

如需自定义配置，可直接运行 `guardiand node` 命令：

```bash
guardiand node \
  --testnetMode \
  --guardianKey=/tmp/guardian.key \
  --dataDir=/tmp/guardian-data \
  --solanaRPC="https://testnet-rpc.1024chain.com/rpc/" \
  --solanaContract="2jBY6fEPcN5rhgMXzQgg5JQcsg8Sp38ud4F3N2vUyUsL" \
  --arbitrumSepoliaRPC="wss://arbitrum-sepolia.drpc.org" \
  --arbitrumSepoliaContract="0x539ADcac182c2Ec8f625c55ae6b048fE8Ce7a3E5"
```

详细参数说明请参考 `guardiand node --help`。

---

### 第 8 步：测试 USDC 跨链

使用 SDK 测试（在 `examples/1024chain-bridge/` 目录）：

```typescript
import { Bridge1024Chain } from './src/bridge';

const bridge = new Bridge1024Chain({
  chain1024: {
    rpcUrl: 'https://testnet-rpc.1024chain.com/rpc/',
    tokenBridgeAddress: '你部署的_Token_Bridge_Address',
  },
  arbitrumSepolia: {
    rpcUrl: 'https://sepolia-rollup.arbitrum.io/rpc',
    tokenBridgeAddress: 'Arbitrum_Token_Bridge地址',
  },
});

// 测试转账：1024Chain → Arbitrum
const result = await bridge.bridgeTokens({
  tokenAddress: '你的USDC_Mint地址',
  amount: '1000000',  // 1 USDC
  recipientAddress: '0x你的Arbitrum钱包地址',
  senderKeyPair: yourKeypair,
  direction: '1024chain-to-arbitrum',
});

console.log('完成！', result);
```

---

## 💡 高级配置（可选）

---

## 🏗️ 完整独立部署方案（生产级）

如果你需要**完全控制**跨链桥系统，包括独立的 Guardian 网络和 Relayer，请按照以下步骤部署：

### 架构概述

```
┌─────────────────────────────────────────────────────────────┐
│                    完整独立跨链桥系统                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  1024Chain                           Arbitrum Sepolia        │
│  ┌─────────────┐                    ┌─────────────┐         │
│  │ Core Bridge │◄───────────────────┤ Core Bridge │         │
│  │Token Bridge │                    │Token Bridge │         │
│  └──────┬──────┘                    └──────┬──────┘         │
│         │                                   │                │
│         │        Guardian Network           │                │
│         │    ┌────────────────────┐        │                │
│         └────┤  Guardian 1 (你的)  │────────┘                │
│              ├────────────────────┤                         │
│              │  Guardian 2        │                         │
│              ├────────────────────┤                         │
│              │  Guardian 3        │                         │
│              ├────────────────────┤                         │
│              │  Guardian 4        │                         │
│              ├────────────────────┤                         │
│              │  Guardian 5        │                         │
│              └────────────────────┘                         │
│                      │                                       │
│                      ▼                                       │
│              ┌────────────────────┐                         │
│              │  Relayer (自部署)   │                         │
│              │  - 自动中继 VAA      │                         │
│              │  - 跨链消息转发      │                         │
│              └────────────────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

---

### 第 1 步：部署合约到两条链

#### 1.1 部署到 1024Chain

```bash
# 使用前面的脚本
./deploy-1024chain.sh

# 记录合约地址
CHAIN1024_CORE_BRIDGE=<输出的地址>
CHAIN1024_TOKEN_BRIDGE=<输出的地址>
```

#### 1.2 部署到 Arbitrum Sepolia

```bash
cd ethereum

# 1. 创建配置文件
cat > env/.env.arbitrum.testnet << EOF
# Arbitrum Sepolia 配置

# RPC 配置
RPC_URL="https://sepolia-rollup.arbitrum.io/rpc"

# Core Bridge 初始化参数
INIT_SIGNERS="[你的Guardian地址数组]"  # 例如: ["0xaddr1","0xaddr2"]
INIT_CHAIN_ID=421614                     # Arbitrum Sepolia Chain ID
INIT_GOV_CHAIN_ID=1                      # 治理链 ID (Solana = 1)
INIT_GOV_CONTRACT="0x0000000000000000000000000000000000000000000000000000000000000004"
INIT_EVM_CHAIN_ID=421614

# Token Bridge 初始化参数
BRIDGE_INIT_CHAIN_ID=421614
BRIDGE_INIT_GOV_CHAIN_ID=1
BRIDGE_INIT_GOV_CONTRACT="0x0000000000000000000000000000000000000000000000000000000000000004"
BRIDGE_INIT_WETH="0x0000000000000000000000000000000000000000"  # Arbitrum Sepolia WETH
BRIDGE_INIT_FINALITY=15
EOF

# 2. 创建符号链接
ln -sf env/.env.arbitrum.testnet .env

# 3. 部署 Core Bridge
MNEMONIC="your_mnemonic_or_private_key" ./sh/deployCoreBridge.sh

# 记录输出的地址
# Wormhole address             | 0x... |
ARBITRUM_CORE_BRIDGE=<从输出复制>

# 4. 部署 Token Bridge
MNEMONIC="your_mnemonic_or_private_key" \
WORMHOLE_ADDRESS=$ARBITRUM_CORE_BRIDGE \
./sh/deployTokenBridge.sh

# 记录输出的地址
ARBITRUM_TOKEN_BRIDGE=<从输出复制>
```

**重要参数说明**：

- `INIT_SIGNERS`: 你的 5 个 Guardian 的 EVM 地址数组（不是公钥，是地址）
- `INIT_CHAIN_ID`: Wormhole Chain ID（Arbitrum Sepolia = 需要查询或自定义）
- `INIT_EVM_CHAIN_ID`: EVM Chain ID（Arbitrum Sepolia = 421614）

---

### 第 2 步：生成 Guardian 密钥

**生成 5 个 Guardian 密钥**：

```bash
cd node

# 为每个 Guardian 生成密钥
for i in {1..5}; do
    ./build/guardiand keygen --desc "Guardian $i" > guardian-$i.key
done

# 提取 Guardian 地址（EVM 地址，用于部署合约）
for i in {1..5}; do
    echo "Guardian $i:"
    cat guardian-$i.key | grep "Addr" | awk '{print $2}'
done
```

**收集 Guardian 地址**：

```bash
# 将上面输出的 5 个地址记录下来，格式如下：
GUARDIAN_ADDRESSES='["0xaddr1","0xaddr2","0xaddr3","0xaddr4","0xaddr5"]'
```

⚠️ **重要**：
- 在第 1 步部署 Arbitrum 合约时，`INIT_SIGNERS` 参数需要使用这些地址
- 这些地址在部署时就写入了合约，**不能后续修改**
- 如果地址不对，需要重新部署合约

**如果需要更新 Guardian Set（仅适用于已有治理权限）**：

只有在你有治理权限且需要更新 Guardian Set 时才使用：

```bash
# 使用 Wormhole 治理机制提交 Guardian Set 更新
# 这需要现有 Guardian Set 的多数签名
# 详见 Wormhole 治理文档
```

---

### 第 3 步：部署 5 个 Guardian 节点

**准备 5 台服务器**（推荐配置）：
- **CPU**: 4 核
- **内存**: 8 GB
- **存储**: 100 GB SSD
- **网络**: 公网 IP + 开放端口 8999 (P2P)

**在每台服务器上部署**：

```bash
# 服务器 1
cd node
make build

# 配置 Guardian 1
cat > config/guardian-1.yaml << EOF
# Guardian 1 配置
nodeName: "guardian-1"
guardianKey: "/path/to/guardian-1.key"

# 网络配置
network: testnet
p2pNetworkID: "/wormhole/1024chain-bridge/1"
p2pPort: 8999
p2pBootstrap: "/dns4/guardian-1.yourdomain.com/udp/8999/quic/p2p/<guardian1_peer_id>"

# 1024Chain
solana:
  rpc: "https://testnet-rpc.1024chain.com/rpc/"
  bridge: "$CHAIN1024_CORE_BRIDGE"
  tokenBridge: "$CHAIN1024_TOKEN_BRIDGE"
  commitment: "finalized"

# Arbitrum Sepolia
ethereum:
  - chainId: 421614
    rpc: "$ARBITRUM_RPC"
    bridge: "$ARBITRUM_CORE_BRIDGE"
    tokenBridge: "$ARBITRUM_TOKEN_BRIDGE"

# 数据库
database:
  path: "/data/guardian-1.db"

# 监控
telemetry:
  enabled: true
  prometheusPort: 8080
EOF

# 启动 Guardian 1
./build/guardiand node --config config/guardian-1.yaml
```

**重复上述步骤配置 Guardian 2-5**：
- 修改 `nodeName`: guardian-2, guardian-3, guardian-4, guardian-5
- 修改 `guardianKey`: 使用对应的密钥文件
- 修改 `database.path`: 不同的数据库路径
- **重要**：所有 Guardian 必须使用**相同的** `p2pNetworkID` 和 `p2pBootstrap`

**验证 Guardian 网络**：

```bash
# 在任意 Guardian 节点查看连接状态
curl http://localhost:8080/metrics | grep guardian_p2p_peers

# 应该看到 4 个 peers（其他 4 个 Guardian）
```

---

### 第 4 步：配置 Quorum（法定人数）

**5 个 Guardian 的 Quorum 计算**：

```
Quorum = floor(2/3 * N) + 1
       = floor(2/3 * 5) + 1
       = floor(3.33) + 1
       = 3 + 1
       = 4
```

**至少需要 4 个 Guardian 签名才能生成有效的 VAA**。

---

### 第 5 步：部署 Relayer

**Relayer 的作用**：
- 监听 Guardian 网络发布的 VAA
- 自动将 VAA 提交到目标链
- 完成跨链消息的最后一步

**部署步骤**：

```bash
cd relayer

# 编译 Relayer
go build -o relayer-engine cmd/relayer/main.go

# 配置 Relayer
cat > config.yaml << EOF
# Relayer 配置
p2p:
  network_id: "/wormhole/1024chain-bridge/1"
  bootstrap_peers:
    - "/dns4/guardian-1.yourdomain.com/udp/8999/quic/p2p/<peer_id>"

# 监听的链
chains:
  - chain_id: 1  # 1024Chain (作为 Solana)
    rpc: "https://testnet-rpc.1024chain.com/rpc/"
    token_bridge: "$CHAIN1024_TOKEN_BRIDGE"
    keypair: "/path/to/relayer-1024chain.json"
    
  - chain_id: 421614  # Arbitrum Sepolia
    rpc: "$ARBITRUM_RPC"
    token_bridge: "$ARBITRUM_TOKEN_BRIDGE"
    private_key: "$RELAYER_ETH_PRIVATE_KEY"

# Relayer 策略
relay_strategy:
  mode: "automatic"  # 自动中继所有 VAA
  filter:
    - token_bridge_only: true  # 只中继 Token Bridge 消息
EOF

# 启动 Relayer
./relayer-engine --config config.yaml
```

---

### 第 6 步：测试完整流程

**1024Chain → Arbitrum 转账测试**：

```bash
# 1. 发起转账
cd examples/1024chain-bridge

npm run transfer -- \
  --from 1024chain \
  --to arbitrum \
  --token $USDC_MINT_ADDRESS \
  --amount 1000000 \
  --recipient 0xYourArbitrumAddress

# 2. 监控 Guardian 日志
# 应该看到 5 个 Guardian 都观察到事件

# 3. 查看 VAA 生成
# 4 个 Guardian 签名后，VAA 生成

# 4. Relayer 自动提交 VAA 到 Arbitrum

# 5. 验证到账
```

---

### 第 7 步：监控和运维

**部署监控系统**：

```yaml
# docker-compose.yml
version: '3'
services:
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"
  
  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
```

**Prometheus 配置**：

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'guardians'
    static_configs:
      - targets:
        - 'guardian-1:8080'
        - 'guardian-2:8080'
        - 'guardian-3:8080'
        - 'guardian-4:8080'
        - 'guardian-5:8080'
```

**关键监控指标**：
- `guardian_p2p_peers`: P2P 连接数（应该 = 4）
- `guardian_observations_total`: 观察到的消息数
- `guardian_vaas_signed_total`: 签名的 VAA 数
- `relayer_vaas_submitted_total`: 提交的 VAA 数

---

### 总结：完整部署清单

**合约部署**：
- ✅ 1024Chain Core Bridge
- ✅ 1024Chain Token Bridge
- ✅ Arbitrum Core Bridge
- ✅ Arbitrum Token Bridge

**Guardian 网络**：
- ✅ 5 个 Guardian 节点（Quorum = 4）
- ✅ Guardian Set 配置
- ✅ P2P 网络连通

**Relayer**：
- ✅ 1 个 Relayer 节点
- ✅ 自动中继配置

**监控**：
- ✅ Prometheus + Grafana
- ✅ 告警配置

**成本估算**：
- 5 台服务器（Guardian）: ~$200-400/月
- 1 台服务器（Relayer）: ~$50/月
- 监控服务器: ~$50/月
- **总计**: ~$300-500/月

---

## 💡 其他高级配置

### 多签钱包管理

如果你要上生产环境，建议使用多签钱包管理合约权限：

**1024Chain 端**：使用 [Squads](https://squads.so)
**Arbitrum 端**：使用 [Gnosis Safe](https://app.safe.global)

具体配置方法请参考各自的官方文档。

### 添加更多代币支持

如果你想支持除 USDC 外的其他代币：

1. 在 1024Chain 上获取代币的 Mint 地址
2. 在 Arbitrum 上部署或找到对应的 ERC20 合约
3. 在 Token Bridge 中注册映射关系
4. 在 SDK 配置中添加新的代币对

## 📚 相关文档

- **API-SPEC.md** - 跨链桥 API 详细文档
- **TEST-PLAN.md** - 测试用例和测试计划
- **PROGRESS.md** - 项目当前进度

## 🔗 外部资源

- [Wormhole 官方文档](https://docs.wormhole.com/)
- [Wormhole GitHub](https://github.com/wormhole-foundation/wormhole)
- [Wormhole Discord](https://discord.gg/wormholecrypto)

---

*最后更新: 2025-11-10*

