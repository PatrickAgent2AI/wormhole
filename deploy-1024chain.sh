#!/bin/bash
# 部署 Wormhole 到 1024Chain（作为 Fogo 测试网）

set -e

cd "$(dirname "$0")/solana"

RPC_URL="https://testnet-rpc.1024chain.com/rpc/"

# 配置 solana CLI
solana config set --url "$RPC_URL"
# 注意：不设置 WebSocket，让它使用默认或在命令中指定

echo "================================================"
echo "  部署 Wormhole 到 1024Chain"
echo "================================================"
echo ""

# 1. 检查钱包
if [ ! -f "payer-fogo-testnet.json" ]; then
    echo "创建部署钱包..."
    solana-keygen new -o payer-fogo-testnet.json --no-bip39-passphrase
fi

DEPLOYER_PUBKEY=$(solana-keygen pubkey payer-fogo-testnet.json)
echo "✓ 部署钱包: $DEPLOYER_PUBKEY"

# 2. 检查余额
echo ""
echo "检查余额..."
# 使用 --url 明确指定 RPC，避免使用 WebSocket
BALANCE=$(solana balance payer-fogo-testnet.json --url "$RPC_URL" 2>/dev/null | grep -oE "[0-9.]+" | head -1)

if [ -z "$BALANCE" ]; then
    BALANCE=0
fi

echo "✓ 当前余额: $BALANCE SOL"
echo "✓ 预计需要: 5-10 SOL（包括部署和后续操作）"

# 使用 awk 代替 bc 进行浮点数比较
NEED_FUNDS=$(awk -v bal="$BALANCE" 'BEGIN { print (bal < 5) ? "yes" : "no" }')

if [ "$NEED_FUNDS" = "yes" ]; then
    echo ""
    echo "⚠️  余额不足！需要充值"
    echo "================================================"
    echo "请向以下地址充值至少 10 SOL："
    echo ""
    echo "  $DEPLOYER_PUBKEY"
    echo ""
    echo "================================================"
    echo ""
    read -p "充值完成后按回车继续..."
    
    # 再次检查余额
    BALANCE=$(solana balance payer-fogo-testnet.json --url "$RPC_URL" 2>/dev/null | grep -oE "[0-9.]+" | head -1)
    echo "✓ 当前余额: $BALANCE SOL"
    
    STILL_NEED_FUNDS=$(awk -v bal="$BALANCE" 'BEGIN { print (bal < 5) ? "yes" : "no" }')
    if [ "$STILL_NEED_FUNDS" = "yes" ]; then
        echo "❌ 余额仍然不足，无法继续部署"
        exit 1
    fi
fi

echo "✓ 余额充足，继续部署..."

# 3. 更新 AUTHORITY
echo ""
echo "更新 Makefile..."
sed -i "s/bridge_AUTHORITY_fogo_testnet=.*/bridge_AUTHORITY_fogo_testnet=$DEPLOYER_PUBKEY/" Makefile
sed -i "s/token_bridge_AUTHORITY_fogo_testnet=.*/token_bridge_AUTHORITY_fogo_testnet=$DEPLOYER_PUBKEY/" Makefile

# 4. 生成程序地址（在编译前）
echo ""
echo "生成程序地址..."

# 为 Bridge 生成 keypair（如果不存在）
if [ ! -f "bridge-keypair.json" ]; then
    solana-keygen new -o bridge-keypair.json --no-bip39-passphrase
fi
BRIDGE_ADDRESS=$(solana-keygen pubkey bridge-keypair.json)
echo "✓ Bridge 程序地址: $BRIDGE_ADDRESS"

# 为 Token Bridge 生成 keypair（如果不存在）
if [ ! -f "token-bridge-keypair.json" ]; then
    solana-keygen new -o token-bridge-keypair.json --no-bip39-passphrase
fi
TOKEN_BRIDGE_ADDRESS=$(solana-keygen pubkey token-bridge-keypair.json)
echo "✓ Token Bridge 程序地址: $TOKEN_BRIDGE_ADDRESS"

# 5. 更新 Makefile（编译前）
echo ""
echo "更新 Makefile 为程序地址..."
sed -i "s/bridge_ADDRESS_fogo_testnet=.*/bridge_ADDRESS_fogo_testnet=$BRIDGE_ADDRESS/" Makefile
sed -i "s/token_bridge_ADDRESS_fogo_testnet=.*/token_bridge_ADDRESS_fogo_testnet=$TOKEN_BRIDGE_ADDRESS/" Makefile

# 6. 编译合约（使用真实地址）
echo ""
echo "编译合约（使用真实程序地址）..."
make artifacts SVM=fogo NETWORK=testnet

# 7. 部署 Bridge
echo ""
echo "部署 Bridge 合约..."
solana program deploy \
    artifacts-fogo-testnet/bridge.so \
    --program-id bridge-keypair.json \
    --keypair payer-fogo-testnet.json \
    --url "$RPC_URL" \
    --with-compute-unit-price 1000 \
    --use-rpc

echo "✓ Bridge 已部署到: $BRIDGE_ADDRESS"

# 8. 部署 Token Bridge
echo ""
echo "部署 Token Bridge 合约..."
solana program deploy \
    artifacts-fogo-testnet/token_bridge.so \
    --program-id token-bridge-keypair.json \
    --keypair payer-fogo-testnet.json \
    --url "$RPC_URL" \
    --with-compute-unit-price 1000 \
    --use-rpc

echo "✓ Token Bridge 已部署到: $TOKEN_BRIDGE_ADDRESS"

echo ""
echo "================================================"
echo "  ✓ 部署完成！"
echo "================================================"
echo ""
echo "部署信息："
echo "  Bridge:        $BRIDGE_ADDRESS"
echo "  Token Bridge:  $TOKEN_BRIDGE_ADDRESS"
echo "  Authority:     $DEPLOYER_PUBKEY"
echo ""
echo "下一步："
echo "  1. 配置 Guardian（使用上述地址）"
echo "  2. 测试 USDC 跨链转账"
echo ""

