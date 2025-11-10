# 测试文档

## 测试策略

测试分为四个层次：
1. **单元测试** - 测试独立函数和方法
2. **集成测试** - 测试组件间交互
3. **端到端测试** - 测试完整跨链流程
4. **边界测试** - 测试边界条件和异常情况

---

## API 单元测试

### Bridge1024Chain 类测试

#### 测试：构造函数

```typescript
describe('Bridge1024Chain', () => {
  describe('constructor', () => {
    test('应该使用默认配置初始化', () => {
      const bridge = new Bridge1024Chain();
      expect(bridge).toBeDefined();
    });
    
    test('应该接受自定义配置', () => {
      const config = {
        chain1024: { rpcUrl: 'https://custom-rpc.io' }
      };
      const bridge = new Bridge1024Chain(config);
      expect(bridge.config.chain1024.rpcUrl).toBe('https://custom-rpc.io');
    });
    
    test('配置缺失时应该抛出错误', () => {
      expect(() => {
        new Bridge1024Chain({
          chain1024: { rpcUrl: '', bridgeAddress: '', tokenBridgeAddress: '' }
        });
      }).toThrow('CHAIN_1024_BRIDGE_ADDRESS is required');
    });
  });
});
```

#### 测试：transferFromChain1024()

```typescript
describe('transferFromChain1024', () => {
  let bridge: Bridge1024Chain;
  let mockKeypair: Keypair;
  
  beforeEach(() => {
    bridge = new Bridge1024Chain();
    mockKeypair = Keypair.generate();
  });
  
  test('成功转账应该返回 TransferResult', async () => {
    const result = await bridge.transferFromChain1024({
      tokenAddress: 'ValidTokenAddress',
      amount: '1000000',
      recipientAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb7',
      senderKeyPair: mockKeypair,
    });
    
    expect(result).toHaveProperty('txHash');
    expect(result).toHaveProperty('sequence');
    expect(result).toHaveProperty('emitterAddress');
  });
  
  test('余额不足应该抛出错误', async () => {
    await expect(
      bridge.transferFromChain1024({
        tokenAddress: 'ValidTokenAddress',
        amount: '999999999999999',  // 超大金额
        recipientAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb7',
        senderKeyPair: mockKeypair,
      })
    ).rejects.toThrow('INSUFFICIENT_BALANCE');
  });
  
  test('无效代币地址应该抛出错误', async () => {
    await expect(
      bridge.transferFromChain1024({
        tokenAddress: 'InvalidAddress',
        amount: '1000000',
        recipientAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb7',
        senderKeyPair: mockKeypair,
      })
    ).rejects.toThrow('TOKEN_NOT_FOUND');
  });
  
  test('无效接收地址应该抛出错误', async () => {
    await expect(
      bridge.transferFromChain1024({
        tokenAddress: 'ValidTokenAddress',
        amount: '1000000',
        recipientAddress: 'InvalidAddress',
        senderKeyPair: mockKeypair,
      })
    ).rejects.toThrow('INVALID_RECIPIENT');
  });
});
```

#### 测试：getSignedVAA()

```typescript
describe('getSignedVAA', () => {
  test('应该成功获取 VAA', async () => {
    const vaa = await bridge.getSignedVAA('123', 'emitter123');
    expect(vaa).toBeInstanceOf(Uint8Array);
    expect(vaa.length).toBeGreaterThan(0);
  });
  
  test('序列号不存在应该超时', async () => {
    await expect(
      bridge.getSignedVAA('999999', 'emitter123')
    ).rejects.toThrow('VAA_TIMEOUT');
  }, 10000);
  
  test('应该在指定时间内重试', async () => {
    const startTime = Date.now();
    await expect(
      bridge.getSignedVAA('invalid', 'invalid')
    ).rejects.toThrow();
    const duration = Date.now() - startTime;
    expect(duration).toBeLessThan(6000);  // 默认超时 5 秒
  });
});
```

---

## 边界测试

### 数值边界

```typescript
describe('边界值测试', () => {
  test('最小转账金额', async () => {
    const result = await bridge.transferFromChain1024({
      tokenAddress: 'ValidTokenAddress',
      amount: '1',  // 最小单位
      recipientAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb7',
      senderKeyPair: keypair,
    });
    expect(result.txHash).toBeDefined();
  });
  
  test('零金额应该抛出错误', async () => {
    await expect(
      bridge.transferFromChain1024({
        tokenAddress: 'ValidTokenAddress',
        amount: '0',
        recipientAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb7',
        senderKeyPair: keypair,
      })
    ).rejects.toThrow();
  });
  
  test('负数金额应该抛出错误', async () => {
    await expect(
      bridge.transferFromChain1024({
        tokenAddress: 'ValidTokenAddress',
        amount: '-100',
        recipientAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb7',
        senderKeyPair: keypair,
      })
    ).rejects.toThrow();
  });
  
  test('超大金额（uint64最大值）', async () => {
    const maxUint64 = '18446744073709551615';
    await expect(
      bridge.transferFromChain1024({
        tokenAddress: 'ValidTokenAddress',
        amount: maxUint64,
        recipientAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb7',
        senderKeyPair: keypair,
      })
    ).rejects.toThrow('INSUFFICIENT_BALANCE');
  });
});
```

### 地址格式边界

```typescript
describe('地址格式边界测试', () => {
  test('Solana 地址长度边界', () => {
    const shortAddress = 'abc';
    const longAddress = 'a'.repeat(100);
    
    expect(() => validateSolanaAddress(shortAddress)).toThrow();
    expect(() => validateSolanaAddress(longAddress)).toThrow();
  });
  
  test('EVM 地址格式边界', () => {
    const validAddress = '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb7';
    const noPrefix = '742d35Cc6634C0532925a3b844Bc9e7595f0bEb7';
    const wrongLength = '0x742d35';
    
    expect(validateEvmAddress(validAddress)).toBe(true);
    expect(() => validateEvmAddress(noPrefix)).toThrow();
    expect(() => validateEvmAddress(wrongLength)).toThrow();
  });
});
```

### 网络异常边界

```typescript
describe('网络异常边界测试', () => {
  test('RPC 超时', async () => {
    const slowBridge = new Bridge1024Chain({
      chain1024: { rpcUrl: 'https://very-slow-rpc.io' }
    });
    
    await expect(
      slowBridge.getStatus()
    ).rejects.toThrow('RPC_ERROR');
  });
  
  test('RPC 不可达', async () => {
    const offlineBridge = new Bridge1024Chain({
      chain1024: { rpcUrl: 'https://non-existent-rpc.io' }
    });
    
    await expect(
      offlineBridge.getStatus()
    ).rejects.toThrow('NETWORK_ERROR');
  });
  
  test('间歇性网络故障重试', async () => {
    let attempts = 0;
    const flakyBridge = new Bridge1024Chain();
    
    // Mock: 前两次失败，第三次成功
    jest.spyOn(flakyBridge, 'getStatus').mockImplementation(async () => {
      attempts++;
      if (attempts < 3) throw new Error('Network error');
      return { chain1024: { connected: true }, arbitrum: { connected: true } };
    });
    
    const result = await retryWithBackoff(() => flakyBridge.getStatus(), 3);
    expect(result.chain1024.connected).toBe(true);
    expect(attempts).toBe(3);
  });
});
```

---

## 集成测试

### Guardian 消息观察测试 ✅

**目标**：验证 Guardian 能够正确观察和处理链上跨链消息。

#### 测试用例 INT-001：Guardian 启动和配置

**步骤：**
1. 执行 `bash scripts/1024chain/start-guardian-final.sh`
2. 等待 5 秒让 Guardian 初始化
3. 检查进程状态：`ps aux | grep guardiand`
4. 检查健康状态：`curl http://localhost:6060/readyz`

**预期结果：**
- Guardian 进程运行中
- 健康检查返回 OK
- 日志显示连接到 3 条链（1024Chain, Ethereum Sepolia, Arbitrum Sepolia）

**实际结果：** ✅ 通过
- Guardian 1: PID 1173310, 地址 0x76c58bA8559589BA3990Ce0A1efcd7039561F530
- Guardian 2: PID 1174605, 地址 0x76dFa2Ff0941bbaa0982A2177e8a68F4B510285A

#### 测试用例 INT-002：发送消息到 Arbitrum Sepolia

**步骤：**
1. 执行 `bash scripts/1024chain/send-test-message.sh <私钥>`
2. 等待交易确认
3. 验证返回的交易哈希

**预期结果：**
- 交易成功确认
- 事件 LogMessagePublished 被触发
- Sequence number 从 1 开始递增

**实际结果：** ✅ 通过
- 交易哈希: 0x5313d3a505999cf0badff1404262fda25341f2d16d3814c108bba8c5c7683c91
- Sequence: 1
- Payload 与发送内容完全一致

#### 测试用例 INT-003：Guardian 观察消息

**步骤：**
1. 发送跨链消息到 Arbitrum Sepolia
2. 自动向 Guardian 发送观察请求（Chain ID: 10003）
3. 查看 Guardian 日志：`tail -f /tmp/guardian.log | grep observation`

**预期结果：**
- Guardian 成功接收观察请求
- Guardian 签名观察记录
- Guardian 发布签名到 P2P 网络

**实际结果：** ✅ 通过
```
INFO sent observation request
INFO published signed observation request
guardian_addr: 0x76c58bA8559589BA3990Ce0A1efcd7039561F530
```

#### 测试用例 INT-004：事件数据一致性验证

**步骤：**
1. 解析链上事件的 data 字段
2. 对比发送的消息内容
3. 验证所有字段（sequence, nonce, payload, consistencyLevel）

**预期结果：**
- 所有字段完全匹配

**实际结果：** ✅ 通过

| 字段 | 发送值 | 事件值 | 状态 |
|------|--------|--------|------|
| Sequence | 1 | 1 | ✅ |
| Nonce | 1762788418 | 1762788418 | ✅ |
| Consistency Level | 1 | 1 | ✅ |
| Payload | "Hello Wormhole..." | "Hello Wormhole..." | ✅ |

#### 测试用例 INT-005：多 Guardian P2P 互联

**步骤：**
1. 启动 Guardian 1 和 Guardian 2
2. 检查 Guardian 2 是否连接到 Guardian 1
3. 向 Guardian 1 发送观察请求
4. 检查 Guardian 2 是否通过 P2P 收到

**预期结果：**
- Guardian 2 成功连接到 Guardian 1
- P2P 消息在两个节点间传播
- 两个节点都连接到 Wormhole Testnet 网络

**实际结果：** ✅ 通过
- 日志显示 p2p_guardian_peer_changed 事件
- 两个 Guardian 都连接到网络

---

### 完整跨链流程测试

```typescript
describe('1024Chain → Arbitrum 完整流程', () => {
  let bridge: Bridge1024Chain;
  let senderKeypair: Keypair;
  let recipientPrivateKey: string;
  
  beforeAll(async () => {
    bridge = new Bridge1024Chain();
    senderKeypair = await loadKeypair('./test-keypair.json');
    recipientPrivateKey = process.env.TEST_ARBITRUM_KEY!;
  });
  
  test('完整跨链转账流程', async () => {
    // 1. 发起转账
    const transferResult = await bridge.transferFromChain1024({
      tokenAddress: TEST_TOKEN_ADDRESS,
      amount: '1000000',
      recipientAddress: TEST_RECIPIENT_ADDRESS,
      senderKeyPair: senderKeypair,
    });
    
    expect(transferResult.txHash).toBeDefined();
    
    // 2. 获取 VAA
    const vaa = await bridge.getSignedVAA(
      transferResult.sequence,
      transferResult.emitterAddress
    );
    
    expect(vaa).toBeDefined();
    expect(vaa.length).toBeGreaterThan(0);
    
    // 3. 在 Arbitrum 赎回
    const redeemTx = await bridge.redeemOnArbitrum(
      vaa,
      recipientPrivateKey
    );
    
    expect(redeemTx).toMatch(/^0x[a-fA-F0-9]{64}$/);
  }, 300000);  // 5 分钟超时
});
```

### 自动化端到端测试

```typescript
describe('自动化 E2E 测试', () => {
  test('bridgeTokens() 完整流程', async () => {
    const result = await bridge.bridgeTokens({
      tokenAddress: TEST_TOKEN_ADDRESS,
      amount: '1000000',
      recipientAddress: TEST_RECIPIENT_ADDRESS,
      senderKeyPair: senderKeypair,
      senderPrivateKey: recipientPrivateKey,
      direction: '1024chain-to-arbitrum',
    });
    
    expect(result.sourceTx).toBeDefined();
    expect(result.redeemTx).toBeDefined();
    
    // 验证余额变化
    const balance = await getArbitrumBalance(
      TEST_RECIPIENT_ADDRESS,
      TEST_TOKEN_ADDRESS
    );
    expect(balance).toBeGreaterThanOrEqual(1000000);
  }, 300000);
});
```

---

## User Stories 和测试计划

### User Story 1: 用户首次跨链转账

**描述**：作为用户，我想从 1024Chain 转账代币到 Arbitrum，以便在 Arbitrum 上使用。

**验收标准**：
1. 用户能够连接钱包
2. 用户能够选择代币和输入数量
3. 系统显示预估费用和到账时间
4. 转账成功后显示交易哈希
5. 用户能够查询转账状态

**测试计划**：

```typescript
describe('User Story 1: 首次跨链转账', () => {
  test('场景1: 正常转账流程', async () => {
    // 1. 连接钱包
    const wallet = await connectWallet();
    expect(wallet.connected).toBe(true);
    
    // 2. 选择代币
    const token = await selectToken('USDC');
    expect(token.address).toBeDefined();
    
    // 3. 输入金额
    const amount = '10';  // 10 USDC
    
    // 4. 获取预估信息
    const estimate = await bridge.estimateFees({
      tokenAddress: token.address,
      amount: parseUnits(amount, token.decimals),
    });
    expect(estimate.fee).toBeDefined();
    expect(estimate.estimatedTime).toBeLessThanOrEqual(180);  // 3分钟内
    
    // 5. 执行转账
    const result = await bridge.bridgeTokens({
      tokenAddress: token.address,
      amount: parseUnits(amount, token.decimals),
      recipientAddress: wallet.arbitrumAddress,
      senderKeyPair: wallet.keypair,
      senderPrivateKey: wallet.arbitrumPrivateKey,
      direction: '1024chain-to-arbitrum',
    });
    
    // 6. 验证结果
    expect(result.sourceTx).toMatch(/^[a-zA-Z0-9]{64,}$/);
    expect(result.redeemTx).toMatch(/^0x[a-fA-F0-9]{64}$/);
  }, 300000);
  
  test('场景2: 余额不足', async () => {
    await expect(
      bridge.bridgeTokens({
        amount: '999999999999',  // 超大金额
        // ...其他参数
      })
    ).rejects.toThrow('INSUFFICIENT_BALANCE');
  });
  
  test('场景3: 网络拥堵导致超时', async () => {
    // Mock 网络拥堵
    jest.setTimeout(400000);
    
    const result = await bridge.bridgeTokens({
      // ...参数
    });
    
    expect(result).toBeDefined();
  }, 400000);
});
```

### User Story 2: 反向转账（Arbitrum → 1024Chain）

**描述**：作为用户，我想从 Arbitrum 转账代币回 1024Chain。

**验收标准**：
1. 支持 ERC20 代币转账
2. 自动处理 Gas 费用
3. 显示转账进度
4. 支持取消待处理的转账

**测试计划**：

```typescript
describe('User Story 2: 反向转账', () => {
  test('场景1: 从 Arbitrum 转回 1024Chain', async () => {
    const result = await bridge.bridgeTokens({
      tokenAddress: ARBITRUM_TOKEN_ADDRESS,
      amount: '1000000',
      recipientAddress: SOLANA_ADDRESS,
      senderPrivateKey: ARBITRUM_PRIVATE_KEY,
      senderKeyPair: SOLANA_KEYPAIR,
      direction: 'arbitrum-to-1024chain',
    });
    
    expect(result.sourceTx).toBeDefined();
    expect(result.redeemTx).toBeDefined();
  }, 300000);
  
  test('场景2: Gas 费用不足', async () => {
    // 使用余额为 0 的账户
    const emptyAccount = new ethers.Wallet('0x...');
    
    await expect(
      bridge.transferFromArbitrum({
        tokenAddress: ARBITRUM_TOKEN_ADDRESS,
        amount: '1000000',
        recipientAddress: SOLANA_ADDRESS,
        senderPrivateKey: emptyAccount.privateKey,
      })
    ).rejects.toThrow('INSUFFICIENT_GAS');
  });
});
```

### User Story 3: 质押代币A获得代币B

**描述**：作为用户，我想质押 1024Chain 上的 USDC，在 Arbitrum 上获得 DAI。

**验收标准**：
1. 支持自定义代币映射
2. 显示兑换比例和滑点
3. 兑换失败时自动回滚
4. 提供兑换历史记录

**测试计划**：

```typescript
describe('User Story 3: 自定义代币映射', () => {
  let customBridge: CustomBridgeSwap;
  
  beforeAll(() => {
    customBridge = new CustomBridgeSwap(SWAP_CONTRACT_ADDRESS);
  });
  
  test('场景1: USDC → DAI 兑换', async () => {
    const result = await customBridge.stakeAndReceiveDifferentToken({
      sourceToken: USDC_1024CHAIN,
      targetToken: DAI_ARBITRUM,
      amount: '1000000',  // 1 USDC
      recipientAddress: USER_ADDRESS,
      senderKeyPair: keypair,
    });
    
    expect(result.sourceToken).toBe(USDC_1024CHAIN);
    expect(result.targetToken).toBe(DAI_ARBITRUM);
    
    // 验证用户收到了 DAI
    const balance = await getTokenBalance(USER_ADDRESS, DAI_ARBITRUM);
    expect(balance).toBeGreaterThan(0);
  }, 300000);
  
  test('场景2: 流动性不足导致失败', async () => {
    await expect(
      customBridge.stakeAndReceiveDifferentToken({
        sourceToken: USDC_1024CHAIN,
        targetToken: RARE_TOKEN_ARBITRUM,  // 流动性极低的代币
        amount: '1000000000',  // 大额
        recipientAddress: USER_ADDRESS,
        senderKeyPair: keypair,
      })
    ).rejects.toThrow();
  });
  
  test('场景3: 滑点保护', async () => {
    const result = await customBridge.stakeAndReceiveDifferentToken({
      sourceToken: USDC_1024CHAIN,
      targetToken: DAI_ARBITRUM,
      amount: '1000000',
      recipientAddress: USER_ADDRESS,
      senderKeyPair: keypair,
      maxSlippage: 0.01,  // 1% 最大滑点
    });
    
    // 验证实际兑换比例在可接受范围内
    const expectedMin = 1000000 * 0.99;  // 1% 滑点
    const actualAmount = await getTokenBalance(USER_ADDRESS, DAI_ARBITRUM);
    expect(actualAmount).toBeGreaterThanOrEqual(expectedMin);
  }, 300000);
});
```

### User Story 4: 批量转账

**描述**：作为大户，我想一次性转账多笔代币到不同地址。

**测试计划**：

```typescript
describe('User Story 4: 批量转账', () => {
  test('场景1: 批量转账10笔', async () => {
    const transfers = Array.from({ length: 10 }, (_, i) => ({
      tokenAddress: TEST_TOKEN_ADDRESS,
      amount: '100000',
      recipientAddress: `recipient_${i}`,
      senderKeyPair: keypair,
    }));
    
    const results = await Promise.all(
      transfers.map(t => bridge.transferFromChain1024(t))
    );
    
    expect(results).toHaveLength(10);
    results.forEach(r => {
      expect(r.txHash).toBeDefined();
    });
  }, 600000);
  
  test('场景2: 部分失败处理', async () => {
    const transfers = [
      { amount: '100000', recipientAddress: 'valid_address' },
      { amount: '100000', recipientAddress: 'invalid_address' },
      { amount: '100000', recipientAddress: 'valid_address_2' },
    ];
    
    const results = await Promise.allSettled(
      transfers.map(t => bridge.transferFromChain1024({
        tokenAddress: TEST_TOKEN_ADDRESS,
        ...t,
        senderKeyPair: keypair,
      }))
    );
    
    const succeeded = results.filter(r => r.status === 'fulfilled');
    const failed = results.filter(r => r.status === 'rejected');
    
    expect(succeeded).toHaveLength(2);
    expect(failed).toHaveLength(1);
  });
});
```

---

## 性能测试

### 吞吐量测试

```typescript
describe('性能测试', () => {
  test('每秒处理转账数', async () => {
    const startTime = Date.now();
    const count = 100;
    
    const transfers = Array.from({ length: count }, () => ({
      tokenAddress: TEST_TOKEN_ADDRESS,
      amount: '100000',
      recipientAddress: TEST_RECIPIENT_ADDRESS,
      senderKeyPair: keypair,
    }));
    
    await Promise.all(
      transfers.map(t => bridge.transferFromChain1024(t))
    );
    
    const duration = (Date.now() - startTime) / 1000;
    const tps = count / duration;
    
    console.log(`TPS: ${tps}`);
    expect(tps).toBeGreaterThan(10);  // 至少 10 TPS
  }, 600000);
});
```

### 内存泄漏测试

```typescript
describe('内存测试', () => {
  test('长时间运行不应有内存泄漏', async () => {
    const initialMemory = process.memoryUsage().heapUsed;
    
    for (let i = 0; i < 1000; i++) {
      await bridge.getStatus();
    }
    
    global.gc();  // 强制垃圾回收
    const finalMemory = process.memoryUsage().heapUsed;
    const memoryIncrease = finalMemory - initialMemory;
    
    // 内存增长应小于 50MB
    expect(memoryIncrease).toBeLessThan(50 * 1024 * 1024);
  });
});
```

---

## 测试执行

### 运行所有测试

```bash
npm test
```

### 运行特定测试

```bash
# 单元测试
npm test -- unit

# 集成测试
npm test -- integration

# E2E 测试
npm test -- e2e

# 特定文件
npm test -- bridge.test.ts
```

### 测试覆盖率

```bash
npm run test:coverage
```

**目标覆盖率**：
- 语句覆盖率: ≥ 90%
- 分支覆盖率: ≥ 85%
- 函数覆盖率: ≥ 90%
- 行覆盖率: ≥ 90%

---

*最后更新: 2025-11-10*

