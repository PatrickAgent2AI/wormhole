#!/bin/bash
# guardian-status.sh - 查看所有 Guardian 节点状态
# 可以从任何位置执行此脚本

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=========================================="
echo "  Guardian 节点状态检查"
echo "=========================================="
echo ""

# Guardian 1
echo "【Guardian 1】"
G1_PID=$(ps aux | grep -v grep | grep "guardiand node.*guardian-1024chain" | awk '{print $2}')
if [ ! -z "$G1_PID" ]; then
  echo "  状态: ✅ 运行中 (PID: $G1_PID)"
  echo "  端口: 6060 (status), 8999 (p2p)"
  echo "  日志: /tmp/guardian.log"
  
  # 获取地址
  G1_ADDR=$(grep "Created the guardian signer" /tmp/guardian.log 2>/dev/null | tail -1 | grep -oP '0x[a-fA-F0-9]+' || echo "N/A")
  echo "  地址: $G1_ADDR"
  
  # 健康检查
  HEALTH=$(curl -s http://localhost:6060/readyz 2>/dev/null | head -1)
  if [ ! -z "$HEALTH" ]; then
    echo "  健康: ✅ 正常"
  else
    echo "  健康: ❌ 异常"
  fi
  
  # 最后日志
  echo "  最新日志:"
  tail -3 /tmp/guardian.log 2>/dev/null | sed 's/^/    /'
else
  echo "  状态: ❌ 未运行"
fi

echo ""
echo "【Guardian 2】"
G2_PID=$(ps aux | grep -v grep | grep "guardiand node.*guardian-2" | awk '{print $2}')
if [ ! -z "$G2_PID" ]; then
  echo "  状态: ✅ 运行中 (PID: $G2_PID)"
  echo "  端口: 6061 (status), 9000 (p2p)"
  echo "  日志: /tmp/guardian-2.log"
  
  # 获取地址
  G2_ADDR=$(grep "Created the guardian signer" /tmp/guardian-2.log 2>/dev/null | tail -1 | grep -oP '0x[a-fA-F0-9]+' || echo "N/A")
  echo "  地址: $G2_ADDR"
  
  # 健康检查
  HEALTH=$(curl -s http://localhost:6061/readyz 2>/dev/null | head -1)
  if [ ! -z "$HEALTH" ]; then
    echo "  健康: ✅ 正常"
  else
    echo "  健康: ❌ 异常"
  fi
  
  # 最后日志
  echo "  最新日志:"
  tail -3 /tmp/guardian-2.log 2>/dev/null | sed 's/^/    /'
else
  echo "  状态: ❌ 未运行"
fi

echo ""
echo "=========================================="
echo "  P2P 网络连接状态"
echo "=========================================="

if [ ! -z "$G1_PID" ]; then
  echo ""
  echo "【Guardian 1 的 P2P 连接】"
  grep "p2p_peer_connected\|p2p_guardian_peer" /tmp/guardian.log 2>/dev/null | tail -3 | sed 's/^/  /'
fi

if [ ! -z "$G2_PID" ]; then
  echo ""
  echo "【Guardian 2 的 P2P 连接】"
  grep "p2p_peer_connected\|p2p_guardian_peer" /tmp/guardian-2.log 2>/dev/null | tail -3 | sed 's/^/  /'
fi

echo ""
echo "=========================================="
echo "  监听的区块链"
echo "=========================================="
echo ""
echo "  - 1024Chain (Solana):     https://testnet-rpc.1024chain.com/rpc/"
echo "  - Ethereum Sepolia:       wss://ethereum-sepolia-rpc.publicnode.com"
echo "  - Arbitrum Sepolia:       wss://arbitrum-sepolia.drpc.org"
echo ""

echo "快捷命令："
echo "  启动 Guardian 1: bash $SCRIPT_DIR/start-guardian-final.sh"
echo "  启动 Guardian 2: bash $SCRIPT_DIR/start-guardian-2.sh"
echo "  停止所有:       pkill -f guardiand"
echo "  实时日志 G1:    tail -f /tmp/guardian.log"
echo "  实时日志 G2:    tail -f /tmp/guardian-2.log"
echo ""

