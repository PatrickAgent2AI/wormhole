#!/bin/bash
# transfer-usdc-arb-to-1024.sh - 从 Arbitrum Sepolia 转账 USDC 到 1024Chain
# 使用方法: bash transfer-usdc-arb-to-1024.sh

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "=========================================="
echo "  从 Arbitrum Sepolia 转账 USDC 到 1024Chain"
echo "=========================================="
echo ""

# ============================================
# 配置区域 - 请根据实际情况修改
# ============================================

# Arbitrum Sepolia 配置
ARB_RPC="https://sepolia-rollup.arbitrum.io/rpc"
ARB_CHAIN_ID="421614"
ARB_WORMHOLE_CHAIN_ID="10003"  # Wormhole Chain ID

# Token Bridge 合约地址（Arbitrum Sepolia 上的官方部署）
TOKEN_BRIDGE="0x50749B80D19c275f4BdC25084Ef8961a739Ae5b3"
WORMHOLE_CORE="0x539ADcac182c2Ec8f625c55ae6b048fE8Ce7a3E5"

# USDC 合约地址（Arbitrum Sepolia 测试网）
# 注意: 这是测试网地址，请替换为实际的 USDC 地址
USDC_TOKEN="0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d"  # Arbitrum Sepolia USDC

# 1024Chain 配置
CHAIN_1024_WORMHOLE_CHAIN_ID="1"  # 1024Chain 被视为 Solana Chain ID

# 转账金额（USDC 是 6 位小数）
AMOUNT="1000000"  # 1 USDC = 1,000,000 (6 decimals)

# ============================================
# 前置检查
# ============================================

echo -e "${BLUE}【步骤 1】前置检查${NC}"
echo "--------------------"

# 检查必需工具
if ! command -v cast &> /dev/null; then
    echo -e "${RED}❌ 错误: 需要安装 Foundry (cast 命令)${NC}"
    echo ""
    echo "安装方法："
    echo "  curl -L https://foundry.paradigm.xyz | bash"
    echo "  foundryup"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ 错误: 需要安装 jq${NC}"
    echo "安装方法: sudo apt-get install jq"
    exit 1
fi

echo -e "${GREEN}✅ 工具检查完成${NC}"
echo ""

# ============================================
# 获取私钥和接收地址
# ============================================

echo -e "${BLUE}【步骤 2】配置钱包信息${NC}"
echo "--------------------"
echo ""

# 从环境变量读取私钥
if [ -z "$PRIVATE_KEY" ]; then
    echo "请输入您的 Arbitrum 钱包私钥（不带 0x 前缀）:"
    echo -e "${YELLOW}⚠️  私钥将仅在本次执行中使用，不会被保存${NC}"
    read -sp "私钥: " PRIVATE_KEY
    echo ""
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}❌ 私钥不能为空${NC}"
    exit 1
fi

# 添加 0x 前缀（如果没有）
if [[ ! $PRIVATE_KEY == 0x* ]]; then
    PRIVATE_KEY="0x$PRIVATE_KEY"
fi

# 获取发送者地址
SENDER=$(cast wallet address --private-key $PRIVATE_KEY)
echo -e "${GREEN}✅ 发送者地址:${NC} $SENDER"

# 获取接收者地址（1024Chain）
echo ""
echo "请输入接收 USDC 的 1024Chain 地址（Base58 格式）:"
echo "示例: 7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU"
read -p "接收地址: " RECIPIENT_1024

if [ -z "$RECIPIENT_1024" ]; then
    echo -e "${RED}❌ 接收地址不能为空${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 接收者地址:${NC} $RECIPIENT_1024"
echo ""

# ============================================
# 检查余额
# ============================================

echo -e "${BLUE}【步骤 3】检查余额${NC}"
echo "--------------------"

# 检查 ETH 余额（用于支付 gas）
ETH_BALANCE=$(cast balance $SENDER --rpc-url $ARB_RPC)
ETH_BALANCE_HUMAN=$(cast --to-unit $ETH_BALANCE ether)
echo "ETH 余额: $ETH_BALANCE_HUMAN ETH"

if (( $(echo "$ETH_BALANCE_HUMAN < 0.001" | bc -l) )); then
    echo -e "${RED}❌ ETH 余额不足，需要至少 0.001 ETH 支付 gas${NC}"
    echo "获取测试 ETH: https://www.alchemy.com/faucets/arbitrum-sepolia"
    exit 1
fi

# 检查 USDC 余额
USDC_BALANCE=$(cast call $USDC_TOKEN "balanceOf(address)(uint256)" $SENDER --rpc-url $ARB_RPC)
USDC_BALANCE_DEC=$((10#${USDC_BALANCE}))
USDC_BALANCE_HUMAN=$(echo "scale=6; $USDC_BALANCE_DEC / 1000000" | bc)
echo "USDC 余额: $USDC_BALANCE_HUMAN USDC"

if [ "$USDC_BALANCE_DEC" -lt "$AMOUNT" ]; then
    echo -e "${RED}❌ USDC 余额不足${NC}"
    echo "需要: $(echo "scale=6; $AMOUNT / 1000000" | bc) USDC"
    echo "当前: $USDC_BALANCE_HUMAN USDC"
    exit 1
fi

echo -e "${GREEN}✅ 余额检查通过${NC}"
echo ""

# ============================================
# 授权 Token Bridge 使用 USDC
# ============================================

echo -e "${BLUE}【步骤 4】授权 Token Bridge 合约${NC}"
echo "--------------------"

# 检查当前授权额度
ALLOWANCE=$(cast call $USDC_TOKEN \
    "allowance(address,address)(uint256)" \
    $SENDER \
    $TOKEN_BRIDGE \
    --rpc-url $ARB_RPC)
ALLOWANCE_DEC=$((10#${ALLOWANCE}))

echo "当前授权额度: $(echo "scale=6; $ALLOWANCE_DEC / 1000000" | bc) USDC"

if [ "$ALLOWANCE_DEC" -lt "$AMOUNT" ]; then
    echo "需要授权 Token Bridge 合约..."
    
    # 授权最大额度（或者只授权需要的数量）
    APPROVE_AMOUNT="115792089237316195423570985008687907853269984665640564039457584007913129639935"  # uint256 max
    
    echo "发送授权交易..."
    APPROVE_TX=$(cast send $USDC_TOKEN \
        "approve(address,uint256)" \
        $TOKEN_BRIDGE \
        $APPROVE_AMOUNT \
        --private-key $PRIVATE_KEY \
        --rpc-url $ARB_RPC \
        --json 2>&1)
    
    APPROVE_TX_HASH=$(echo "$APPROVE_TX" | jq -r '.transactionHash' 2>/dev/null || echo "")
    
    if [ -z "$APPROVE_TX_HASH" ] || [ "$APPROVE_TX_HASH" = "null" ]; then
        echo -e "${RED}❌ 授权失败${NC}"
        echo "$APPROVE_TX"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 授权成功${NC}"
    echo "   交易哈希: $APPROVE_TX_HASH"
    echo "   浏览器: https://sepolia.arbiscan.io/tx/$APPROVE_TX_HASH"
    
    # 等待确认
    echo "等待交易确认..."
    sleep 5
else
    echo -e "${GREEN}✅ 已有足够的授权额度${NC}"
fi

echo ""

# ============================================
# 转换接收地址为 bytes32 格式
# ============================================

echo -e "${BLUE}【步骤 5】准备跨链转账${NC}"
echo "--------------------"

# 将 1024Chain 地址（Base58）转换为 bytes32
# 对于 Solana/1024Chain，需要先将 Base58 解码为 32 字节
# 这里使用一个 Python 脚本来完成转换

RECIPIENT_HEX=$(python3 << EOF
import base58
import sys

try:
    address_bytes = base58.b58decode('$RECIPIENT_1024')
    if len(address_bytes) != 32:
        print("error", file=sys.stderr)
        sys.exit(1)
    print('0x' + address_bytes.hex())
except Exception as e:
    print("error", file=sys.stderr)
    sys.exit(1)
EOF
)

if [ "$RECIPIENT_HEX" = "error" ] || [ -z "$RECIPIENT_HEX" ]; then
    echo -e "${RED}❌ 无法转换接收地址${NC}"
    echo "请确保地址格式正确"
    
    # 尝试备用方法：使用 bs58 命令行工具
    if command -v bs58 &> /dev/null; then
        echo "尝试使用 bs58 工具..."
        RECIPIENT_HEX="0x$(echo -n $RECIPIENT_1024 | bs58 -d | xxd -p -c 32)"
    else
        echo "安装 base58 Python 库: pip3 install base58"
        exit 1
    fi
fi

echo "接收地址 (bytes32): $RECIPIENT_HEX"

# 获取消息费用
MSG_FEE=$(cast call $WORMHOLE_CORE "messageFee()(uint256)" --rpc-url $ARB_RPC)
MSG_FEE_ETH=$(cast --to-unit $MSG_FEE ether)
echo "Wormhole 消息费用: $MSG_FEE_ETH ETH"

echo ""

# ============================================
# 发起跨链转账
# ============================================

echo -e "${BLUE}【步骤 6】发起跨链转账${NC}"
echo "--------------------"
echo ""
echo "转账信息："
echo "  代币: USDC ($USDC_TOKEN)"
echo "  数量: $(echo "scale=6; $AMOUNT / 1000000" | bc) USDC"
echo "  从: Arbitrum Sepolia ($SENDER)"
echo "  到: 1024Chain ($RECIPIENT_1024)"
echo "  消息费用: $MSG_FEE_ETH ETH"
echo ""

read -p "确认发送? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "已取消"
    exit 0
fi

echo ""
echo "发送转账交易..."

# 调用 Token Bridge 的 transferTokens 函数
# function transferTokens(
#     address token,
#     uint256 amount,
#     uint16 recipientChain,
#     bytes32 recipient,
#     uint256 arbiterFee,
#     uint32 nonce
# ) 
TX_OUTPUT=$(cast send $TOKEN_BRIDGE \
    "transferTokens(address,uint256,uint16,bytes32,uint256,uint32)" \
    $USDC_TOKEN \
    $AMOUNT \
    $CHAIN_1024_WORMHOLE_CHAIN_ID \
    $RECIPIENT_HEX \
    0 \
    $(date +%s) \
    --private-key $PRIVATE_KEY \
    --rpc-url $ARB_RPC \
    --value $MSG_FEE \
    --json 2>&1)

TX_HASH=$(echo "$TX_OUTPUT" | jq -r '.transactionHash' 2>/dev/null || echo "")

if [ -z "$TX_HASH" ] || [ "$TX_HASH" = "null" ]; then
    echo -e "${RED}❌ 转账失败${NC}"
    echo "$TX_OUTPUT"
    exit 1
fi

echo -e "${GREEN}✅ 转账交易已发送！${NC}"
echo ""
echo "交易哈希: $TX_HASH"
echo "浏览器: https://sepolia.arbiscan.io/tx/$TX_HASH"
echo ""

# ============================================
# 等待确认并获取 VAA 信息
# ============================================

echo -e "${BLUE}【步骤 7】等待交易确认${NC}"
echo "--------------------"

# 等待交易确认
echo "等待区块确认..."
for i in {1..60}; do
    RECEIPT=$(cast receipt $TX_HASH --rpc-url $ARB_RPC --json 2>/dev/null || echo "")
    if [ ! -z "$RECEIPT" ]; then
        STATUS=$(echo "$RECEIPT" | jq -r '.status')
        if [ "$STATUS" = "0x1" ]; then
            BLOCK_NUMBER=$(echo "$RECEIPT" | jq -r '.blockNumber')
            echo -e "${GREEN}✅ 交易已确认 (区块: $BLOCK_NUMBER)${NC}"
            break
        else
            echo -e "${RED}❌ 交易失败${NC}"
            echo "$RECEIPT" | jq '.'
            exit 1
        fi
    fi
    echo "   等待中... ($i/60)"
    sleep 2
done

echo ""

# 解析日志获取 sequence number
echo "解析 VAA 信息..."
# LogMessagePublished event signature
EVENT_SIG="0x6eb224fb001ed210e379b335e35efe88672a8ce935d981a6896b27ffdf52a3b2"

SEQUENCE=$(echo "$RECEIPT" | jq -r ".logs[] | select(.topics[0] == \"$EVENT_SIG\") | .topics[2]" | head -1)

if [ ! -z "$SEQUENCE" ] && [ "$SEQUENCE" != "null" ]; then
    SEQUENCE_DEC=$((16#${SEQUENCE:2}))
    echo -e "${GREEN}✅ VAA Sequence Number: $SEQUENCE_DEC${NC}"
    
    # 获取 emitter address (Token Bridge)
    EMITTER=$(cast call $TOKEN_BRIDGE "wormhole()(address)" --rpc-url $ARB_RPC)
    echo "Emitter Address: $EMITTER"
    
    # 构建 VAA ID
    VAA_ID="${ARB_WORMHOLE_CHAIN_ID}/${EMITTER}/${SEQUENCE_DEC}"
    echo ""
    echo -e "${BLUE}VAA 查询信息:${NC}"
    echo "  VAA ID: $VAA_ID"
    echo ""
fi

echo ""

# ============================================
# Guardian 观察检查
# ============================================

echo -e "${BLUE}【步骤 8】检查 Guardian 观察${NC}"
echo "--------------------"
echo ""
echo "Guardian 节点会自动观察到这笔交易"
echo "预计等待时间: 2-5 分钟"
echo ""

echo "可以使用以下命令监控："
echo ""
echo "1. 查看 Guardian 日志:"
echo "   tail -f /tmp/guardian.log | grep -i \"$TX_HASH\""
echo ""
echo "2. 手动请求观察 (如果自动观察失败):"
echo "   guardiand admin send-observation-request \\"
echo "     --socket /tmp/sockets/admin.sock \\"
echo "     $ARB_WORMHOLE_CHAIN_ID \\"
echo "     $TX_HASH"
echo ""
echo "3. 查询 VAA (生成后):"
echo "   guardiand admin dump-vaa-by-message-id \\"
echo "     --socket /tmp/sockets/admin.sock \\"
echo "     $VAA_ID"
echo ""

# ============================================
# 下一步操作指引
# ============================================

echo ""
echo "=========================================="
echo "  🎉 跨链转账已发起！"
echo "=========================================="
echo ""
echo -e "${YELLOW}📝 下一步操作:${NC}"
echo ""
echo "1. 等待 Guardian 生成 VAA (2-5 分钟)"
echo ""
echo "2. 获取 VAA 后，在 1024Chain 上赎回 USDC"
echo "   - VAA 将包含在 Guardian 签名中"
echo "   - 使用 1024Chain 的 Token Bridge 合约赎回"
echo ""
echo "3. 验证 1024Chain 上的余额"
echo ""
echo -e "${GREEN}转账信息已保存:${NC}"
echo "  交易哈希: $TX_HASH"
echo "  区块浏览器: https://sepolia.arbiscan.io/tx/$TX_HASH"
if [ ! -z "$SEQUENCE_DEC" ]; then
    echo "  VAA Sequence: $SEQUENCE_DEC"
    echo "  VAA ID: $VAA_ID"
fi
echo ""
echo "测试完成！"
echo ""

