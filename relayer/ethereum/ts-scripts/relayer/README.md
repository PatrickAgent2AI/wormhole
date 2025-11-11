# How to use these scripts

## Configuration

Private keys should be placed in a .env file corresponding to the Environment you intend to work in. For example, tilt private keys should be kept in ./.env.tilt

If you do not set an environment, the 'default' environment will be used, and .env will be read.

All other configuration is done through files in the ./config/\${env} directory.

./config/\${env}/chains.json is the file which controls how many chains will be executed against, as well as their RPC and basic info.

./config/\${env}/contracts.json is the file which allows you to target specific contracts on each chain.

./config/\${env}/scriptConfigs contains custom configurations for individual scripts. Not all scripts have custom arguments.

## Generic Relayer Configuration (1024Chain Integration)

### Quick Start

To run the generic relayer for 1024Chain integration:

```bash
# 1. Start Redis (if in Docker environment)
docker run -d --name redis -p 6379:6379 redis:latest

# 2. Start Guardian with Arbitrum Sepolia support
./scripts/1024chain/start-guardian-final.sh

# 3. Start Spy service
./scripts/1024chain/start-spy.sh

# 4. Start Relayer with proper configuration
export EVM_PRIVATE_KEY='your_private_key_here'
export NON_INTERACTIVE=1
./scripts/1024chain/start-relayer.sh
```

### Key Configuration Points

#### 1. Wormhole Chain IDs
- **Arbitrum Sepolia**: Chain ID `10003`
- **1024Chain (Solana-based)**: Chain ID `1`
- **Ethereum Sepolia**: Chain ID `2`

#### 2. Contracts Configuration (`config/testnet/contracts.json`)

The generic relayer needs to know which WormholeRelayer contracts to monitor:

```json
{
  "wormholeRelayers": [
    {
      "chainId": 10003,
      "address": "0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470"
    }
  ],
  "deliveryProviders": [
    {
      "chainId": 10003,
      "address": "0x7A0a53847776f7e94Cc35742971aCb2217b0Db81"
    }
  ]
}
```

#### 3. RPC Configuration (Environment Variable)

Set via `BLOCKCHAIN_PROVIDERS` environment variable:

```bash
export BLOCKCHAIN_PROVIDERS='{
  "chains": {
    "10003": {
      "endpoints": ["https://sepolia-rollup.arbitrum.io/rpc"]
    },
    "1": {
      "endpoints": ["https://testnet-rpc.1024chain.com/rpc/"]
    }
  }
}'
```

#### 4. Guardian Configuration

Guardian must be configured to watch Arbitrum Sepolia:

```bash
--arbitrumSepoliaRPC='wss://sepolia-rollup.arbitrum.io/feed'
--arbitrumSepoliaContract='0x6b9C8671cdDC8dEab9c719bB87cBd3e782bA6a35'
```

#### 5. Spy Configuration

Spy must connect to Guardian's P2P network:

```bash
--spyRPC="[::]:7072"
--env=testnet
--port=8998  # Different from Guardian's 8999
```

### Testing the Configuration

#### Important: Generic Relayer vs. Simple Messages

**The generic relayer ONLY processes delivery requests**, not simple `publishMessage` calls.

The current `send-test-message.sh` calls `publishMessage()` which creates a VAA but **no delivery instruction**. The generic relayer will ignore these.

To properly test the relayer, you need to:

1. **Option A**: Use WormholeRelayer contract to send a delivery request:
```solidity
IWormholeRelayer(relayerAddress).sendPayloadToEvm{value: cost}(
    targetChain,
    targetAddress,
    payload,
    receiverValue,
    gasLimit
);
```

2. **Option B**: Deploy a mock integration contract that uses the relayer:
```bash
# Deploy mock integration on Arbitrum Sepolia
ENV=testnet ts-node ./ts-scripts/relayer/mockIntegration/deployMockIntegration.ts

# Send a test message through the integration
ENV=testnet ts-node ./ts-scripts/relayer/mockIntegration/messageTest.ts
```

#### Send Test Message (Simple VAA - for Guardian/Spy testing only)

```bash
./scripts/1024chain/send-test-message.sh
```

This will:
1. Send a message to Wormhole Core on Arbitrum Sepolia
2. Guardian observes and signs the VAA
3. Spy receives the VAA
4. **BUT**: Generic Relayer will ignore it (no delivery instructions)

#### Expected Relayer Logs

**For proper delivery requests** (from WormholeRelayer contract), you should see:

```
info: connected to the spy at: localhost:7072
debug: [
  {
    "emitterFilter": {
      "chainId": 10003,
      "emitterAddress": "0000000000000000000000007b1bd7a6b4e61c2a123ac6bc2cbfc614437d0470"
    }
  }
]
info: Processing generic relayer vaa
info: Detected delivery VAA, processing delivery payload...
debug: Fetching vaas from parsed delivery vaa manifest...
debug: Processing delivery
debug: Warming up wallet toolbox for chain...
debug: Pulling balances for 0x...
info: Estimated transaction cost (ether): 0.001234
debug: Sending 'deliver' tx...
info: Relayed instruction to chain 1, tx hash: 0x...
info: Delivery Success
```

**For simple `publishMessage` calls** (like `send-test-message.sh`):
- Relayer will receive the VAA through Spy
- But will **NOT** process it (no "Processing generic relayer vaa" log)
- This is expected behavior - generic relayer only processes delivery instructions

**How to verify the setup is working**:
1. Check Spy is receiving VAAs:
   ```bash
   tail -f /tmp/spy.log | grep -i "received.*vaa"
   ```

2. Check Relayer is connected to Spy:
   ```bash
   # Should show "connected to the spy"
   tail -f /tmp/relayer.log | grep -i "spy"
   ```

3. Check Relayer is monitoring the correct contracts:
   ```bash
   # Should show emitterAddress matching WormholeRelayer contract
   tail -f /tmp/relayer.log | grep -i "emitterFilter"
   ```

### Troubleshooting

#### Problem 1: Relayer not processing VAA

**Symptoms:**
- Spy receives VAA (check with `tail -f /tmp/spy.log`)
- But no "Processing generic relayer vaa" logs in relayer

**Root Cause:**
The VAA is not a delivery request. Generic relayer only processes VAAs from WormholeRelayer contracts.

**Solution:**
1. Verify the VAA comes from a WormholeRelayer contract:
   ```bash
   # Check emitter address in relayer logs
   # Should match WormholeRelayer address: 0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470
   ```

2. If using `send-test-message.sh`, this is expected - use mock integration instead:
   ```bash
   ENV=testnet ts-node ./ts-scripts/relayer/mockIntegration/messageTest.ts
   ```

3. Check Guardian is observing Arbitrum Sepolia:
   ```bash
   tail -f /tmp/guardian.log | grep -i arbitrum
   ```

4. Manually request observation (for debugging):
   ```bash
   guardiand admin send-observation-request \
     --socket /tmp/sockets/admin.sock \
     10003 \
     0xYOUR_TX_HASH
   ```

#### Problem 2: Wrong Chain ID

**Symptoms:**
```
Error: Invalid chain name: base
Error: could not detect network
```

**Solution:**
- Ensure `env.ts` filters unsupported chains (Chain ID 30 - Base is filtered)
- Check `contracts.json` only contains supported chains
- Verify Chain ID mapping: Arbitrum Sepolia = 10003 (NOT 10002)

#### Problem 3: Redis Connection Failed

**Symptoms:**
```
Error: connect ECONNREFUSED 127.0.0.1:6379
```

**Solution (Docker environment):**
```bash
# Use Docker bridge gateway
export REDIS_HOST="172.17.0.1"
export REDIS_PORT=6379
```

#### Problem 4: Missing Contract Configuration

**Symptoms:**
- Relayer starts but ignores VAAs
- No "Processing generic relayer vaa" logs

**Solution:**
1. Verify `wormholeRelayers` in contracts.json includes your source chain
2. Check `deliveryProviders` matches the VAA's delivery provider
3. Ensure contract addresses are checksummed (0x7B1b... not 0x7b1b...)

#### Problem 5: Guardian Not Observing Transactions

**Symptoms:**
- Transaction confirmed on-chain
- Guardian logs show no observation

**Solution:**
1. Check Guardian RPC connection:
   ```bash
   # Guardian should show successful RPC calls
   tail -f /tmp/guardian.log | grep "arbitrum.*connected\|arbitrum.*rpc"
   ```

2. Verify Wormhole Core contract address:
   ```bash
   # Should match: 0x6b9C8671cdDC8dEab9c719bB87cBd3e782bA6a35
   grep arbitrumSepoliaContract scripts/1024chain/start-guardian-final.sh
   ```

3. Check if using correct Chain ID in send script (10003 not 10002)

### Monitoring

#### View Relayer Metrics

```bash
curl http://localhost:3000/metrics
```

#### View Relayer UI

```bash
# Open in browser
http://localhost:3000/ui
```

#### Check Service Status

```bash
./scripts/1024chain/check-relayer-services.sh
```

### Docker Environment Notes

When running inside Docker container:
- `localhost` refers to container, not host
- Use `172.17.0.1` for Docker bridge gateway
- Redis container needs explicit port mapping
- Guardian/Spy need to be accessible from container

### Architecture Overview

```
[Arbitrum Sepolia]
       ↓ (Transaction)
[Wormhole Core Contract]
       ↓ (Event)
[Guardian Network] → [Spy Service (7072)]
       ↓ (VAA)              ↓
[Guardian REST (7071)]  [Relayer App]
                            ↓
                        [Redis Queue]
                            ↓
                    [Process & Deliver]
                            ↓
                      [1024Chain]
```

### Additional Resources

- **Guardian Status**: `./scripts/1024chain/guardian-status.sh`
- **VAA Checker**: `./scripts/1024chain/check-vaa-ready.sh`
- **Contract Addresses**: [SDK Relayer Consts](../../../../../sdk/js/src/relayer/consts.ts)

### Important Notes

1. **Chain ID Mismatch**: Arbitrum Sepolia uses Chain ID 10003 in Wormhole, not 10002
2. **Contract Addresses**: Always use checksummed addresses from official SDK
3. **RPC Endpoints**: WebSocket (`wss://`) for Guardian, HTTPS for Relayer
4. **Private Keys**: Never commit private keys, use environment variables
5. **Wallet Balance**: Ensure relayer wallet has sufficient gas on target chains

## Running the scripts

All files in the coreRelayer, deliveryProvider, and MockIntegration directories are runnable. These are intended to run from the /ethereum directory.

The target environment must be passed in as an environment variable. So, for example, you can run the DeliveryProvider deployment script by running:

```
ENV=tilt ts-node ./ts-scripts/relayer/deliveryProvider/deployDeliveryProvider.ts
```

## Chaining multiple scripts

Scripts are meant to be run individually or successively. Scripts which deploy contracts will write the deployed addresses into the ./output folder.

If "useLastRun" is set to true in the contracts.json configuration file, the lastrun files from the deployment scripts will be used, rather than the deployed addresses of the contracts.json file. This allows you to easily run things like

```
ENV=tilt ts-node ./ts-scripts/relayer/deliveryProvider/upgradeDeliveryProvider.ts && ts-node ./ts-scripts/relayer/mockIntegration/messageTest.ts
```

The ./shell directory contains shell scripts which combine commonly chained actions together.

For example, ./shell/deployConfigureTest.sh will deploy the DeliveryProvider, WormholeRelayer, and MockIntegration contracts. Configure them all to point at each other, and then run messageTest to test that everything worked. Note: useLastRun in contracts.json needs to be set to "true" in order for this script to work.
