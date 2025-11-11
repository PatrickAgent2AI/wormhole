#!/bin/bash
# start-guardian-2.sh - Guardian 2 启动脚本
# 可以从任何位置执行此脚本

set -e

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 合约地址配置
CHAIN_1024_BRIDGE="2jBY6fEPcN5rhgMXzQgg5JQcsg8Sp38ud4F3N2vUyUsL"
# Arbitrum Sepolia Core Bridge地址 (根据ethereum/README.md中的部署信息)
ARBITRUM_SEPOLIA_WORMHOLE="0x6b9C8671cdDC8dEab9c719bB87cBd3e782bA6a35"

# 第一个 Guardian 的 P2P 信息（需要先启动 guardian-1）
GUARDIAN_1_PEER_ID="12D3KooWGRJf1B9Lk47AkVHkcGrGjGb3bVGCq7wwfrgyDovZ2D8L"
GUARDIAN_1_IP="127.0.0.1"
GUARDIAN_1_PORT="8999"

# 创建第二个 Guardian 的目录
mkdir -p /tmp/guardian-2-data /tmp/guardian-2-sockets

# 生成第二个 Guardian 的密钥（如果不存在）
if [ ! -f "/tmp/guardian-2.key" ]; then
  echo "生成第二个 Guardian 密钥..."
  guardiand keygen /tmp/guardian-2.key --desc "Guardian 2 for 1024Chain"
fi

# 确保权限正确
if id guardian >/dev/null 2>&1; then
  chown -R guardian:guardian /tmp/guardian-2-data /tmp/guardian-2-sockets /tmp/guardian-2.key /tmp/node-2.key 2>/dev/null || true
fi

echo "启动第二个 Guardian 节点（本地独立P2P网络）..."
echo "⚠️  使用自定义P2P网络，完全隔离！"
echo "配置："
echo "  数据目录: /tmp/guardian-2-data"
echo "  Status 端口: 6061 (第一个用 6060)"
echo "  P2P 端口: 9000 (第一个用 8999)"
echo "  Bootstrap: 连接到第一个 Guardian"
echo "  日志文件: /tmp/guardian-2.log"
echo ""

# 等待获取Guardian 1的Peer ID
echo "等待获取 Guardian 1 的 Peer ID..."
sleep 5

# 尝试多种方式获取 Guardian 1 的 Peer ID
GUARDIAN_1_PEER_ID=$(grep -oP "our_peer_id.*12D3[a-zA-Z0-9]+" /tmp/guardian.log | tail -1 | grep -oP "12D3[a-zA-Z0-9]+")
if [ -z "$GUARDIAN_1_PEER_ID" ]; then
    GUARDIAN_1_PEER_ID=$(grep -oP "node-id.*12D3[a-zA-Z0-9]+" /tmp/guardian.log | head -1 | grep -oP "12D3[a-zA-Z0-9]+")
fi
if [ -z "$GUARDIAN_1_PEER_ID" ]; then
    GUARDIAN_1_PEER_ID=$(grep -oP "peer\.ID.*12D3[a-zA-Z0-9]+" /tmp/guardian.log | head -1 | grep -oP "12D3[a-zA-Z0-9]+")
fi
if [ -z "$GUARDIAN_1_PEER_ID" ]; then
    echo "❌ 无法从日志获取Guardian 1的Peer ID"
    echo "请确保 Guardian 1 已经启动，并查看日志："
    echo "  tail -20 /tmp/guardian.log | grep -i 'peer\|p2p'"
    exit 1
fi

echo "  Guardian 1 Peer ID: $GUARDIAN_1_PEER_ID"
echo ""

# 使用 guardian 用户在后台启动
# testnetMode: 允许禁用心跳验证等测试特性
# network: 使用与Guardian 1相同的自定义网络ID
# bootstrap: 连接到Guardian 1
su - guardian -c "nohup guardiand node \
  --testnetMode \
  --network='/wormhole/local/1024chain' \
  --nodeName='guardian-local-2' \
  --guardianKey=/tmp/guardian-2.key \
  --nodeKey=/tmp/node-2.key \
  --dataDir=/tmp/guardian-2-data \
  --adminSocket=/tmp/guardian-2-sockets/admin.sock \
  --publicGRPCSocket=/tmp/guardian-2-sockets/publicgrpc.sock \
  --statusAddr=':6061' \
  --logLevel=debug \
  --disableTelemetry \
  --disableHeartbeatVerify \
  --port=9000 \
  --bootstrap='/ip4/$GUARDIAN_1_IP/udp/$GUARDIAN_1_PORT/quic/p2p/$GUARDIAN_1_PEER_ID' \
  --ethRPC='wss://ethereum-sepolia-rpc.publicnode.com' \
  --ethContract='0x4a8bc80Ed5a4067f1CCf107057b8270E0cC11A78' \
  --solanaRPC='https://testnet-rpc.1024chain.com/rpc/' \
  --solanaContract='$CHAIN_1024_BRIDGE' \
  --arbitrumSepoliaRPC='wss://arb-sepolia.g.alchemy.com/v2/demo' \
  --arbitrumSepoliaContract='$ARBITRUM_SEPOLIA_WORMHOLE' \
  > /tmp/guardian-2.log 2>&1 &"

sleep 3

# 检查进程状态
GUARDIAN_2_PID=$(ps aux | grep -v grep | grep "guardiand node.*guardian-2" | awk '{print $2}')

if [ ! -z "$GUARDIAN_2_PID" ]; then
  echo "✅ 第二个 Guardian 节点启动成功！PID: $GUARDIAN_2_PID"
  
  # 获取 Guardian 地址
  sleep 2
  GUARDIAN_2_ADDR=$(grep "Created the guardian signer" /tmp/guardian-2.log | tail -1 | grep -oP '0x[a-fA-F0-9]+' || echo "正在初始化...")
  GUARDIAN_2_PEER=$(grep "Found existing node key\|generated node key" /tmp/guardian-2.log | tail -1 | grep -oP '12D3[a-zA-Z0-9]+' || echo "正在初始化...")
  
  echo ""
  echo "Guardian 2 信息："
  echo "  地址: $GUARDIAN_2_ADDR"
  echo "  Peer ID: $GUARDIAN_2_PEER"
  echo ""
  echo "管理命令："
  echo "  查看日志: tail -f /tmp/guardian-2.log"
  echo "  检查状态: curl http://localhost:6061/readyz"
  echo "  查看 RPC: guardiand admin dump-rpcs --socket /tmp/guardian-2-sockets/admin.sock"
  echo "  停止节点: kill $GUARDIAN_2_PID"
  echo ""
  echo "查看两个 Guardian 的网络连接："
  echo "  Guardian 1 日志: tail -f /tmp/guardian.log | grep p2p"
  echo "  Guardian 2 日志: tail -f /tmp/guardian-2.log | grep p2p"
else
  echo "❌ 第二个 Guardian 节点启动失败，查看日志："
  tail -30 /tmp/guardian-2.log
fi

