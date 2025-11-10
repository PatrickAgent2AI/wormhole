#!/bin/bash
# start-guardian.sh
set -e

# 替换为你的实际合约地址
CHAIN_1024_BRIDGE="2jBY6fEPcN5rhgMXzQgg5JQcsg8Sp38ud4F3N2vUyUsL"
ARBITRUM_SEPOLIA_WORMHOLE="0x539ADcac182c2Ec8f625c55ae6b048fE8Ce7a3E5"

# 创建必要的目录
mkdir -p /tmp/guardian-data /tmp/sockets

# 生成密钥（如果不存在）
if [ ! -f "/tmp/guardian.key" ]; then
  echo "生成 Guardian 密钥..."
  guardiand keygen /tmp/guardian.key --desc "1024Chain Guardian"
fi

# 确保目录权限正确（如果当前是 root 用户）
if [ "$(id -u)" -eq 0 ] && id guardian >/dev/null 2>&1; then
  chown -R guardian:guardian /tmp/guardian-data /tmp/sockets /tmp/guardian.key /tmp/node.key 2>/dev/null || true
fi

echo "启动 Guardian 节点..."
echo "监听端口: 6060 (status), 8999 (p2p)"
echo ""

# 启动 Guardian 节点
guardiand node \
  --unsafeDevMode \
  --nodeName="guardian-1024chain" \
  --disableHeartbeatVerify \
  \
  `# 密钥和数据` \
  --guardianKey=/tmp/guardian.key \
  --nodeKey=/tmp/node.key \
  --dataDir=/tmp/guardian-data \
  \
  `# 管理接口` \
  --adminSocket=/tmp/sockets/admin.sock \
  --publicGRPCSocket=/tmp/sockets/publicgrpc.sock \
  --statusAddr=":6060" \
  \
  `# 日志和监控配置` \
  --logLevel=info \
  --disableTelemetry \
  \
  `# P2P 网络配置` \
  --port=8999 \
  \
  `# Ethereum Sepolia（必需配置至少一个以太坊链）` \
  --ethRPC="wss://ethereum-sepolia-rpc.publicnode.com" \
  --ethContract="0x4a8bc80Ed5a4067f1CCf107057b8270E0cC11A78" \
  \
  `# 1024Chain 配置（基于 Solana）` \
  --solanaRPC="https://testnet-rpc.1024chain.com/rpc/" \
  --solanaContract="$CHAIN_1024_BRIDGE" \
  \
  `# Arbitrum Sepolia 配置（必须使用 WebSocket）` \
  --arbitrumSepoliaRPC="wss://sepolia-rollup.arbitrum.io/rpc" \
  --arbitrumSepoliaContract="$ARBITRUM_SEPOLIA_WORMHOLE"

