#!/bin/bash
# send-test-message.sh - 发送测试消息到 Arbitrum Sepolia
# 可以从任何位置执行此脚本

set -e

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 配置
WORMHOLE_CORE="0x539ADcac182c2Ec8f625c55ae6b048fE8Ce7a3E5"
ARB_RPC="https://sepolia-rollup.arbitrum.io/rpc"
EVM_CHAIN_ID="421614"  # Arbitrum Sepolia EVM Chain ID
WORMHOLE_CHAIN_ID="10003"  # Arbitrum Sepolia 在 Wormhole 中的 Chain ID

echo "=========================================="
echo "  发送测试消息到 Arbitrum Sepolia"
echo "=========================================="
echo ""
echo "Wormhole Core: $WORMHOLE_CORE"
echo ""

# 检查私钥
if [ -z "$1" ]; then
    echo "用法: $0 <PRIVATE_KEY>"
    echo ""
    echo "示例:"
    echo "  export PRIVATE_KEY=0x..."
    echo "  $0 \$PRIVATE_KEY"
    exit 1
fi

PRIVATE_KEY="$1"

# 获取发送者地址
SENDER=$(cast wallet address --private-key "$PRIVATE_KEY" 2>/dev/null || echo "error")
if [ "$SENDER" = "error" ]; then
    echo "❌ 无效的私钥"
    exit 1
fi

echo "发送者: $SENDER"

# 检查余额
BALANCE=$(cast balance "$SENDER" --rpc-url "$ARB_RPC")
BALANCE_ETH=$(cast --to-unit "$BALANCE" ether)
echo "余额: $BALANCE_ETH ETH"
echo ""

# 准备消息
TIMESTAMP=$(date +%s)
MESSAGE="Hello Wormhole from Arbitrum Sepolia at $TIMESTAMP"
PAYLOAD="0x$(echo -n "$MESSAGE" | xxd -p | tr -d '\n')"
NONCE=$TIMESTAMP
CONSISTENCY_LEVEL=1

echo "消息内容: $MESSAGE"
echo "Payload: $PAYLOAD"
echo "Nonce: $NONCE"
echo ""

# 发送交易
echo "发送交易..."
cast send "$WORMHOLE_CORE" \
    "publishMessage(uint32,bytes,uint8)" \
    "$NONCE" \
    "$PAYLOAD" \
    "$CONSISTENCY_LEVEL" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$ARB_RPC" \
    --confirmations 1 \
    --json | tee /tmp/tx_result.json

echo ""

# 解析结果
if [ -f /tmp/tx_result.json ]; then
    TX_HASH=$(jq -r '.transactionHash // .hash // empty' /tmp/tx_result.json)
    
    if [ ! -z "$TX_HASH" ] && [ "$TX_HASH" != "null" ]; then
        echo "✅ 交易已发送！"
        echo ""
        echo "交易哈希: $TX_HASH"
        echo "浏览器: https://sepolia.arbiscan.io/tx/$TX_HASH"
        echo ""
        
        # 获取交易收据
        echo "等待交易确认..."
        sleep 5
        
        RECEIPT=$(cast receipt "$TX_HASH" --rpc-url "$ARB_RPC" --json 2>/dev/null || echo "")
        
        if [ ! -z "$RECEIPT" ]; then
            BLOCK=$(echo "$RECEIPT" | jq -r '.blockNumber')
            STATUS=$(echo "$RECEIPT" | jq -r '.status')
            
            if [ "$STATUS" = "0x1" ]; then
                echo "✅ 交易已确认（区块 $BLOCK）"
                
                # 解析 sequence
                SEQUENCE_HEX=$(echo "$RECEIPT" | jq -r '.logs[] | select(.topics[0] == "0x6eb224fb001ed210e379b335e35efe88672a8ce935d981a6896b27ffdf52a3b2") | .topics[2]' | head -1)
                
                if [ ! -z "$SEQUENCE_HEX" ] && [ "$SEQUENCE_HEX" != "null" ]; then
                    SEQUENCE=$((16#${SEQUENCE_HEX:2}))
                    echo "   Sequence: $SEQUENCE"
                fi
                
                echo ""
                echo "=========================================="
                echo "  🎉 成功！"
                echo "=========================================="
                echo ""
                echo "现在测试 Guardian 观察："
                echo ""
                echo "【方法 1】手动请求观察"
                echo "--------------------"
                echo "guardiand admin send-observation-request \\"
                echo "  --socket /tmp/sockets/admin.sock \\"
                echo "  $WORMHOLE_CHAIN_ID \\"
                echo "  $TX_HASH"
                echo ""
                echo "【方法 2】查看日志"
                echo "--------------------"
                echo "tail -f /tmp/guardian.log | grep -i \"$TX_HASH\""
                echo ""
                echo "【方法 3】监控 Arbitrum 事件"
                echo "--------------------"
                echo "tail -f /tmp/guardian.log | grep -i \"arbitrum.*observation\""
                echo ""
                
                # 自动请求观察
                echo "自动发送观察请求..."
                echo "  使用 Wormhole Chain ID: $WORMHOLE_CHAIN_ID (Arbitrum Sepolia)"
                
                if [ -S /tmp/sockets/admin.sock ]; then
                    guardiand admin send-observation-request \
                        --socket /tmp/sockets/admin.sock \
                        "$WORMHOLE_CHAIN_ID" \
                        "$TX_HASH" 2>&1 && echo "✅ 观察请求已发送到 Guardian 1"
                fi
                
                if [ -S /tmp/guardian-2-sockets/admin.sock ]; then
                    guardiand admin send-observation-request \
                        --socket /tmp/guardian-2-sockets/admin.sock \
                        "$WORMHOLE_CHAIN_ID" \
                        "$TX_HASH" 2>&1 && echo "✅ 观察请求已发送到 Guardian 2"
                fi
                
                echo ""
                echo "等待 10 秒后检查日志..."
                sleep 10
                
                echo ""
                echo "【Guardian 1 最新日志】"
                tail -20 /tmp/guardian.log | grep -i "arbitrum\|observation\|$TX_HASH" || echo "  暂无相关日志"
                
                echo ""
                echo "【Guardian 2 最新日志】"
                tail -20 /tmp/guardian-2.log | grep -i "arbitrum\|observation\|$TX_HASH" || echo "  暂无相关日志"
                
            else
                echo "❌ 交易失败（状态: $STATUS）"
            fi
        fi
    else
        echo "❌ 无法获取交易哈希"
        cat /tmp/tx_result.json
    fi
else
    echo "❌ 交易失败"
fi

