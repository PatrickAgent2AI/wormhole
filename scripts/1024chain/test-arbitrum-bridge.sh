#!/bin/bash
# test-arbitrum-bridge.sh - 测试 Arbitrum Sepolia Token Bridge 与 Guardian 集成
# 可以从任何位置执行此脚本

set -e

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=========================================="
echo "  Arbitrum Sepolia Token Bridge 测试"
echo "=========================================="
echo ""

# 从部署文档读取的配置
ARB_SEPOLIA_RPC="https://sepolia-rollup.arbitrum.io/rpc"
ARB_CHAIN_ID="421614"
WORMHOLE_CORE="0x539ADcac182c2Ec8f625c55ae6b048fE8Ce7a3E5"
TOKEN_BRIDGE="0x50749B80D19c275f4BdC25084Ef8961a739Ae5b3"

echo "部署信息："
echo "  链:           Arbitrum Sepolia"
echo "  Chain ID:     $ARB_CHAIN_ID"
echo "  RPC:          $ARB_SEPOLIA_RPC"
echo "  Wormhole:     $WORMHOLE_CORE"
echo "  Token Bridge: $TOKEN_BRIDGE"
echo ""

# 检查 Guardian 状态
echo "【检查 Guardian 状态】"
echo "--------------------"
bash "$SCRIPT_DIR/guardian-status.sh" | head -30
echo ""

# 检查工具
if ! command -v cast &> /dev/null; then
    echo "❌ 错误: 需要安装 Foundry"
    echo ""
    echo "安装方法："
    echo "  curl -L https://foundry.paradigm.xyz | bash"
    echo "  foundryup"
    exit 1
fi

echo "✅ Foundry 工具已安装"
echo ""

# 测试 1: 验证合约部署
echo "【测试 1】验证 Wormhole Core 合约"
echo "--------------------"

GUARDIAN_SET_INDEX=$(cast call $WORMHOLE_CORE \
  "getCurrentGuardianSetIndex()(uint32)" \
  --rpc-url $ARB_SEPOLIA_RPC 2>/dev/null || echo "error")

if [ "$GUARDIAN_SET_INDEX" = "error" ]; then
    echo "❌ 无法连接到 Wormhole Core 合约"
    exit 1
fi

echo "✅ Wormhole Core 合约可访问"
echo "   Guardian Set Index: $GUARDIAN_SET_INDEX"

# 获取 Guardian Set
echo ""
echo "查询当前 Guardian Set..."
GUARDIAN_SET=$(cast call $WORMHOLE_CORE \
  "getGuardianSet(uint32)(address[],uint32)" \
  $GUARDIAN_SET_INDEX \
  --rpc-url $ARB_SEPOLIA_RPC 2>/dev/null || echo "error")

if [ "$GUARDIAN_SET" != "error" ]; then
    echo "✅ Guardian Set 信息:"
    echo "$GUARDIAN_SET"
fi

# 获取消息费用
MSG_FEE=$(cast call $WORMHOLE_CORE \
  "messageFee()(uint256)" \
  --rpc-url $ARB_SEPOLIA_RPC 2>/dev/null || echo "0")
echo "   Message Fee: $MSG_FEE wei"

# 获取 finality
FINALITY=$(cast call $WORMHOLE_CORE \
  "finality()(uint8)" \
  --rpc-url $ARB_SEPOLIA_RPC 2>/dev/null || echo "1")
echo "   Finality: $FINALITY blocks"

echo ""

# 测试 2: 验证 Token Bridge
echo "【测试 2】验证 Token Bridge 合约"
echo "--------------------"

WORMHOLE_ADDR=$(cast call $TOKEN_BRIDGE \
  "wormhole()(address)" \
  --rpc-url $ARB_SEPOLIA_RPC 2>/dev/null || echo "error")

if [ "$WORMHOLE_ADDR" = "error" ]; then
    echo "❌ 无法连接到 Token Bridge 合约"
    exit 1
fi

echo "✅ Token Bridge 合约可访问"
echo "   关联的 Wormhole: $WORMHOLE_ADDR"

# 验证地址匹配
if [ "${WORMHOLE_ADDR,,}" = "${WORMHOLE_CORE,,}" ]; then
    echo "   ✅ Token Bridge 正确关联到 Wormhole Core"
else
    echo "   ⚠️  地址不匹配！"
fi

echo ""

# 测试 3: 查看最近的消息
echo "【测试 3】查看最近发布的消息"
echo "--------------------"

LATEST_BLOCK=$(cast block-number --rpc-url $ARB_SEPOLIA_RPC)
FROM_BLOCK=$((LATEST_BLOCK - 1000))

echo "搜索区块范围: $FROM_BLOCK - $LATEST_BLOCK"
echo ""

# LogMessagePublished event signature
# event LogMessagePublished(address indexed sender, uint64 sequence, uint32 nonce, bytes payload, uint8 consistencyLevel)
EVENT_SIG="0x6eb224fb001ed210e379b335e35efe88672a8ce935d981a6896b27ffdf52a3b2"

echo "查询 LogMessagePublished 事件..."
EVENTS=$(cast logs \
  --from-block $FROM_BLOCK \
  --to-block $LATEST_BLOCK \
  --address $WORMHOLE_CORE \
  $EVENT_SIG \
  --rpc-url $ARB_SEPOLIA_RPC 2>/dev/null || echo "")

if [ -z "$EVENTS" ]; then
    echo "⚠️  最近 1000 个区块内没有找到消息发布事件"
else
    EVENT_COUNT=$(echo "$EVENTS" | jq -r '.[] | .transactionHash' | wc -l)
    echo "✅ 找到 $EVENT_COUNT 个消息发布事件"
    echo ""
    echo "最近的事件（前3个）:"
    echo "$EVENTS" | jq -r '.[] | "\(.blockNumber) | TX: \(.transactionHash)"' | head -3
fi

echo ""
echo ""

# 测试 4: 发送测试消息
echo "【测试 4】发送测试消息到 Wormhole Core"
echo "--------------------"
echo ""
echo "⚠️  这将在 Arbitrum Sepolia 上发送一条测试消息"
echo "   需要："
echo "   1. 钱包私钥"
echo "   2. 至少 0.001 ETH (用于 gas)"
echo ""

read -p "是否继续发送测试消息? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "⏭️  跳过消息发送"
    echo ""
    echo "=========================================="
    echo "  手动测试步骤"
    echo "=========================================="
    echo ""
    echo "你可以使用 cast 手动发送消息："
    echo ""
    echo "cast send $WORMHOLE_CORE \\"
    echo "  'publishMessage(uint32,bytes,uint8)' \\"
    echo "  0 \\"
    echo "  0x48656c6c6f20576f726d686f6c65 \\"
    echo "  1 \\"
    echo "  --private-key \$PRIVATE_KEY \\"
    echo "  --rpc-url $ARB_SEPOLIA_RPC \\"
    echo "  --value $MSG_FEE"
    echo ""
    exit 0
fi

echo ""
read -sp "请输入私钥: " PRIVATE_KEY
echo ""

if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ 私钥不能为空"
    exit 1
fi

# 获取发送者地址
SENDER=$(cast wallet address --private-key $PRIVATE_KEY)
echo "发送者地址: $SENDER"

# 检查余额
BALANCE=$(cast balance $SENDER --rpc-url $ARB_SEPOLIA_RPC)
BALANCE_ETH=$(cast --to-unit $BALANCE ether)
echo "余额: $BALANCE_ETH ETH"

# 使用 awk 代替 bc 进行浮点数比较
BALANCE_CHECK=$(awk -v bal="$BALANCE_ETH" 'BEGIN { print (bal < 0.001) ? "low" : "ok" }')
if [ "$BALANCE_CHECK" = "low" ]; then
    echo "⚠️  余额可能不足以支付 gas 费"
    read -p "继续? (yes/no): " PROCEED
    if [ "$PROCEED" != "yes" ]; then
        exit 0
    fi
fi

# 准备测试消息
TIMESTAMP=$(date +%s)
TEST_PAYLOAD="0x$(echo -n "Test from Arbitrum Sepolia at $TIMESTAMP" | xxd -p)"
NONCE=$TIMESTAMP
CONSISTENCY_LEVEL=1  # finalized

echo ""
echo "准备发送消息..."
echo "  Payload: $TEST_PAYLOAD"
echo "  Nonce: $NONCE"
echo "  Consistency Level: $CONSISTENCY_LEVEL"
echo "  Message Fee: $MSG_FEE wei"
echo ""

# 发送消息
echo "发送交易..."
TX_OUTPUT=$(cast send $WORMHOLE_CORE \
    "publishMessage(uint32,bytes,uint8)" \
    "$NONCE" "$TEST_PAYLOAD" "$CONSISTENCY_LEVEL" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$ARB_SEPOLIA_RPC" \
    --json 2>&1 || echo "error")

if echo "$TX_OUTPUT" | grep -q "error"; then
    echo "❌ 发送交易失败:"
    echo "$TX_OUTPUT"
    exit 1
fi

TX_HASH=$(echo "$TX_OUTPUT" | jq -r '.transactionHash' 2>/dev/null || echo "")

if [ -z "$TX_HASH" ] || [ "$TX_HASH" = "null" ]; then
    echo "❌ 无法获取交易哈希"
    echo "$TX_OUTPUT"
    exit 1
fi

echo "✅ 交易已发送！"
echo "   交易哈希: $TX_HASH"
echo "   浏览器: https://sepolia.arbiscan.io/tx/$TX_HASH"
echo ""

# 等待确认
echo "等待交易确认..."
for i in {1..30}; do
    RECEIPT=$(cast receipt $TX_HASH --rpc-url $ARB_SEPOLIA_RPC --json 2>/dev/null || echo "")
    if [ ! -z "$RECEIPT" ]; then
        STATUS=$(echo "$RECEIPT" | jq -r '.status')
        if [ "$STATUS" = "0x1" ]; then
            echo "✅ 交易已确认（区块 $(echo "$RECEIPT" | jq -r '.blockNumber')）"
            break
        else
            echo "❌ 交易失败"
            exit 1
        fi
    fi
    echo "   等待中... ($i/30)"
    sleep 2
done

# 解析 sequence number
SEQUENCE=$(echo "$RECEIPT" | jq -r '.logs[] | select(.topics[0] == "'$EVENT_SIG'") | .topics[2]' | head -1)

if [ ! -z "$SEQUENCE" ] && [ "$SEQUENCE" != "null" ]; then
    SEQUENCE_DEC=$((16#${SEQUENCE:2}))
    echo "   Sequence Number: $SEQUENCE_DEC"
fi

echo ""
echo "=========================================="
echo "  🎉 测试消息发送成功！"
echo "=========================================="
echo ""
echo "现在测试 Guardian 是否能观察到这条消息："
echo ""
echo "【方法 1】手动请求观察"
echo "--------------------"
echo "guardiand admin send-observation-request \\"
echo "  --socket /tmp/sockets/admin.sock \\"
echo "  $ARB_CHAIN_ID \\"
echo "  $TX_HASH"
echo ""
echo "【方法 2】查看 Guardian 日志"
echo "--------------------"
echo "# Guardian 1"
echo "tail -f /tmp/guardian.log | grep -i \"$TX_HASH\|arbitrum\|observation\""
echo ""
echo "# Guardian 2"
echo "tail -f /tmp/guardian-2.log | grep -i \"$TX_HASH\|arbitrum\|observation\""
echo ""
echo "【方法 3】等待自动观察（推荐）"
echo "--------------------"
echo "Guardian 会自动扫描新区块并观察消息"
echo "通常在 $FINALITY 个区块确认后开始处理"
echo ""
echo "等待 30 秒后查看日志..."

sleep 30

echo ""
echo "检查 Guardian 日志中是否有相关记录..."
echo ""

# 检查 Guardian 1
G1_LOG=$(grep -i "arbitrum\|$ARB_CHAIN_ID" /tmp/guardian.log 2>/dev/null | tail -5 || echo "")
if [ ! -z "$G1_LOG" ]; then
    echo "【Guardian 1 最新日志】"
    echo "$G1_LOG"
    echo ""
fi

# 检查 Guardian 2
G2_LOG=$(grep -i "arbitrum\|$ARB_CHAIN_ID" /tmp/guardian-2.log 2>/dev/null | tail -5 || echo "")
if [ ! -z "$G2_LOG" ]; then
    echo "【Guardian 2 最新日志】"
    echo "$G2_LOG"
    echo ""
fi

echo "=========================================="
echo "  测试完成"
echo "=========================================="
echo ""
echo "提示："
echo "  - 如果 Guardian 日志中没有显示，可能需要更长时间等待"
echo "  - 检查 Guardian 的 Arbitrum Sepolia watcher 是否正常运行"
echo "  - 使用 'bash /workspace/wormhole/guardian-status.sh' 查看状态"
echo ""

