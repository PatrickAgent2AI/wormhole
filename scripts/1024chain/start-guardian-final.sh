#!/bin/bash
# start-guardian-final.sh - Guardian 1 启动脚本
# 可以从任何位置执行此脚本

set -e

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 合约地址配置
CHAIN_1024_BRIDGE="2jBY6fEPcN5rhgMXzQgg5JQcsg8Sp38ud4F3N2vUyUsL"
ARBITRUM_SEPOLIA_WORMHOLE="0x539ADcac182c2Ec8f625c55ae6b048fE8Ce7a3E5"

# 创建必要的目录
mkdir -p /tmp/guardian-data /tmp/sockets

# 确保权限正确
if id guardian >/dev/null 2>&1; then
  chown -R guardian:guardian /tmp/guardian-data /tmp/sockets /tmp/guardian.key /tmp/node.key 2>/dev/null || true
fi

echo "启动 Guardian 节点..."
echo "Guardian 地址: 0x76c58bA8559589BA3990Ce0A1efcd7039561F530"
echo "监听端口: 6060 (status), 8999 (p2p)"
echo "日志文件: /tmp/guardian.log"
echo ""

# 使用 guardian 用户在后台启动
su - guardian -c "nohup guardiand node \
  --testnetMode \
  --nodeName='guardian-1024chain' \
  --guardianKey=/tmp/guardian.key \
  --nodeKey=/tmp/node.key \
  --dataDir=/tmp/guardian-data \
  --adminSocket=/tmp/sockets/admin.sock \
  --publicGRPCSocket=/tmp/sockets/publicgrpc.sock \
  --statusAddr=':6060' \
  --logLevel=info \
  --disableTelemetry \
  --disableHeartbeatVerify \
  --port=8999 \
  --ethRPC='wss://ethereum-sepolia-rpc.publicnode.com' \
  --ethContract='0x4a8bc80Ed5a4067f1CCf107057b8270E0cC11A78' \
  --solanaRPC='https://testnet-rpc.1024chain.com/rpc/' \
  --solanaContract='$CHAIN_1024_BRIDGE' \
  --arbitrumSepoliaRPC='wss://sepolia-rollup.arbitrum.io/feed' \
  --arbitrumSepoliaContract='$ARBITRUM_SEPOLIA_WORMHOLE' \
  > /tmp/guardian.log 2>&1 &"

sleep 3

# 检查进程状态
if ps aux | grep -v grep | grep "guardiand node" > /dev/null; then
  echo "✅ Guardian 节点启动成功！"
  echo ""
  echo "管理命令："
  echo "  查看日志: tail -f /tmp/guardian.log"
  echo "  检查状态: curl http://localhost:6060/readyz"
  echo "  查看 RPC: guardiand admin dump-rpcs --socket /tmp/sockets/admin.sock"
  echo "  停止节点: pkill -f guardiand"
else
  echo "❌ Guardian 节点启动失败，查看日志："
  tail -20 /tmp/guardian.log
fi

