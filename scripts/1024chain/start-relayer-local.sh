#!/bin/bash

# 启动本地Relayer（监听Guardian VAA并提交到1024chain）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/../.."

echo "=== 启动本地Relayer ==="
echo ""

# 检查环境
check_prerequisites() {
    echo "检查环境依赖..."
    
    # 检查Guardian是否运行
    if ! curl -s http://localhost:7071/metrics > /dev/null 2>&1; then
        echo "❌ Guardian未运行，请先启动Guardian"
        echo "   运行: bash $SCRIPT_DIR/start-guardian-local.sh"
        exit 1
    fi
    echo "✅ Guardian运行中"
    
    # 检查Node.js
    if ! command -v node &> /dev/null; then
        echo "❌ Node.js未安装"
        exit 1
    fi
    echo "✅ Node.js已安装"
    
    # 检查是否有payer密钥
    if [ ! -f "$PROJECT_ROOT/solana/payer-local.json" ]; then
        echo "⚠️  本地payer密钥不存在，创建新密钥..."
        solana-keygen new --no-passphrase -o "$PROJECT_ROOT/solana/payer-local.json"
    fi
    
    PAYER_ADDRESS=$(solana-keygen pubkey "$PROJECT_ROOT/solana/payer-local.json")
    echo "✅ Payer地址: $PAYER_ADDRESS"
}

# 启动relayer脚本
start_relayer() {
    echo ""
    echo "启动Relayer监听器..."
    echo "配置:"
    echo "  - Guardian REST API: http://localhost:7071"
    echo "  - 1024chain RPC: http://localhost:8545"
    echo "  - Core Bridge: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"
    echo "  - Token Bridge: 0x0165878A594ca255338adfa4d48449f69242Eb8F"
    echo ""
    
    # 运行relayer脚本
    cd "$SCRIPT_DIR"
    node simple-relayer-local.js
}

# 执行
check_prerequisites
start_relayer

