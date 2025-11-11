#!/bin/bash
# start-guardian-local.sh - Guardian 连接本地Anvil测试链
set -e

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 本地Anvil合约地址
LOCAL_WORMHOLE="0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"

# 创建必要的目录
mkdir -p /tmp/guardian-local-data /tmp/sockets-local

# 确保权限正确
if id guardian >/dev/null 2>&1; then
  chown -R guardian:guardian /tmp/guardian-local-data /tmp/sockets-local 2>/dev/null || true
fi

echo "启动 Guardian 节点（连接本地Anvil测试链）..."
echo "Guardian 地址: 0x76c58bA8559589BA3990Ce0A1efcd7039561F530"
echo "本地Anvil Core Bridge: $LOCAL_WORMHOLE"
echo "⚠️  使用本地独立P2P网络"
echo "监听端口:"
echo "  - 6060: Status API"
echo "  - 7070: Public gRPC (用于 Relayer)"
echo "  - 7071: Public REST (用于 Relayer)"
echo "  - 8999: P2P 网络"
echo "日志文件: /tmp/guardian-local.log"
echo ""

# 使用现有的guardian.key（地址: 0x76c58bA8559589BA3990Ce0A1efcd7039561F530）
if [ ! -f "/tmp/guardian.key" ]; then
  echo "❌ /tmp/guardian.key不存在"
  exit 1
fi

# 使用现有的node.key
if [ ! -f "/tmp/node.key" ]; then
  echo "❌ /tmp/node.key不存在"
  exit 1
fi

# 使用 guardian 用户在后台启动
# testnetMode + 自定义网络ID实现本地隔离
su - guardian -c "nohup guardiand node \
  --testnetMode \
  --network='/wormhole/local/anvil' \
  --bootstrap='' \
  --nodeName='guardian-anvil-1' \
  --guardianKey=/tmp/guardian.key \
  --nodeKey=/tmp/node.key \
  --dataDir=/tmp/guardian-local-data \
  --adminSocket=/tmp/sockets-local/admin.sock \
  --publicGRPCSocket=/tmp/sockets-local/publicgrpc.sock \
  --statusAddr=':6060' \
  --publicRPC='[::]:7070' \
  --publicWeb='[::]:7071' \
  --logLevel=info \
  --disableTelemetry \
  --disableHeartbeatVerify \
  --port=8999 \
  --ethRPC='ws://localhost:8545' \
  --ethContract='$LOCAL_WORMHOLE' \
  --logLevel=debug \
  > /tmp/guardian-local.log 2>&1 &"

sleep 5

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
  echo "管理命令："
  echo "  查看日志: tail -f /tmp/guardian-local.log"
  echo "  检查状态: curl http://localhost:6060/readyz"
  echo "  停止节点: pkill -f guardiand"
  echo ""
  echo "Guardian地址: 0xbeFA429d57cD18b7F8A4d91A2da9AB4AF05d0FBe"
else
  echo "❌ Guardian 节点启动失败，查看日志："
  tail -50 /tmp/guardian-local.log
fi

