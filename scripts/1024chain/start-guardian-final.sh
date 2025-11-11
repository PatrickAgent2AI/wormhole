#!/bin/bash
# start-guardian-final.sh - Guardian 1 启动脚本
# 可以从任何位置执行此脚本

set -e

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 合约地址配置
CHAIN_1024_BRIDGE="2jBY6fEPcN5rhgMXzQgg5JQcsg8Sp38ud4F3N2vUyUsL"
# Arbitrum Sepolia Core Bridge地址 (根据ethereum/README.md中的部署信息)
ARBITRUM_SEPOLIA_WORMHOLE="0x6b9C8671cdDC8dEab9c719bB87cBd3e782bA6a35"

# 创建必要的目录
mkdir -p /tmp/guardian-data /tmp/sockets

# 确保权限正确
if id guardian >/dev/null 2>&1; then
  chown -R guardian:guardian /tmp/guardian-data /tmp/sockets /tmp/guardian.key /tmp/node.key 2>/dev/null || true
fi

echo "启动 Guardian 1 节点（本地独立P2P网络）..."
echo "⚠️  使用自定义P2P网络，完全隔离！"
echo "监听端口:"
echo "  - 6060: Status API"
echo "  - 7070: Public gRPC (用于 Relayer)"
echo "  - 7071: Public REST (用于 Relayer)"
echo "  - 8999: P2P 网络"
echo "日志文件: /tmp/guardian.log"
echo ""

# 使用 guardian 用户在后台启动
# testnetMode: 允许禁用心跳验证等测试特性
# network: 自定义网络ID '/wormhole/local/1024chain' - 完全隔离的本地P2P网络
# bootstrap: 空字符串表示这是第一个节点（bootstrap节点）
su - guardian -c "nohup guardiand node \
  --testnetMode \
  --network='/wormhole/local/1024chain' \
  --bootstrap='' \
  --nodeName='guardian-local-1' \
  --guardianKey=/tmp/guardian.key \
  --nodeKey=/tmp/node.key \
  --dataDir=/tmp/guardian-data \
  --adminSocket=/tmp/sockets/admin.sock \
  --publicGRPCSocket=/tmp/sockets/publicgrpc.sock \
  --statusAddr=':6060' \
  --publicRPC='[::]:7070' \
  --publicWeb='[::]:7071' \
  --logLevel=debug \
  --disableTelemetry \
  --disableHeartbeatVerify \
  --port=8999 \
  --ethRPC='wss://ethereum-sepolia-rpc.publicnode.com' \
  --ethContract='0x4a8bc80Ed5a4067f1CCf107057b8270E0cC11A78' \
  --solanaRPC='https://testnet-rpc.1024chain.com/rpc/' \
  --solanaContract='$CHAIN_1024_BRIDGE' \
  --arbitrumSepoliaRPC='wss://arb-sepolia.g.alchemy.com/v2/demo' \
  --arbitrumSepoliaContract='$ARBITRUM_SEPOLIA_WORMHOLE' \
  > /tmp/guardian.log 2>&1 &"

sleep 3

# 检查进程状态
if ps aux | grep -v grep | grep "guardiand node" > /dev/null; then
  echo "✅ Guardian 节点启动成功！"
  echo ""
  echo "接口地址："
  echo "  Status API:     http://localhost:6060/readyz"
  echo "  Public gRPC:    localhost:7070"
  echo "  Public REST:    http://localhost:7071"
  echo "  P2P Network:    udp://localhost:8999"
  echo ""
  echo "Relayer 配置："
  echo "  wormholeRpcs:   [\"http://localhost:7071\"]"
  echo ""
  echo "管理命令："
  echo "  查看日志: tail -f /tmp/guardian.log"
  echo "  检查状态: curl http://localhost:6060/readyz"
  echo "  测试 REST: curl http://localhost:7071/v1/signed_vaa/2/000000000000000000000000b6f6d86a8f9879a9c87f643768d9efc38c1da6e7/1"
  echo "  查看 RPC: guardiand admin dump-rpcs --socket /tmp/sockets/admin.sock"
  echo "  停止节点: pkill -f guardiand"
else
  echo "❌ Guardian 节点启动失败，查看日志："
  tail -20 /tmp/guardian.log
fi

