# Wormhole bridge - ETH

These smart contracts allow to use Ethereum as foreign chain in the Wormhole protocol.

The `Wormhole` contract is the bridge contract and allows tokens to be transferred out of ETH and VAAs to be submitted
to transfer tokens in or change configuration settings.

The `WrappedAsset` is a ERC-20 token contract that holds metadata about a wormhole asset on ETH. Wormhole assets are all
wrapped non-ETH assets that are currently held on ETH.

### Building

To build the contracts:
`make build`

### Deploying using Forge

#### Create the ENV file

Before you can deploy the contracts, you need to create a file in `ethereum/env` with a name like `.env.blast` for mainnet
or `.env.blast.testnet` for testnet. Substitute the appropriate chain name (as it will be in the worm client) and use the
mentioned one as an example.

#### Create a symbolic link

```shell
ethereum$ ln -s env/.env.blast.testnet .env
```

#### Deploy the Core contract

```shell
ethereum$ MNEMONIC=<redacted> ./sh/deployCoreBridge.sh
```
-- Wormhole Core Addresses --------------------------------------------------
| Setup address                | 0xc987ccbB0a7709B601AC72e91a1bd04e9068baE7 |
| Implementation address       | 0xC957c5a9e670B2BbD21139b4Db421E6e78a0d5c4 |
| Wormhole address             | 0x539ADcac182c2Ec8f625c55ae6b048fE8Ce7a3E5

#### Deploy the TokenBridge contract

```shell
ethereum$ MNEMONIC=<redacted> WORMHOLE_ADDRESS=<from_the_previous_command> ./sh/deployTokenBridge.sh
```
-- TokenBridge Addresses ----------------------------------------------------
| Token Implementation address | 0x66b3BF545AcC64Eb5517524821de6a8289531DfC |
| BridgeSetup address          | 0x421D44cB202367F466981677105D09D453e26D96 |
| BridgeImplementation address | 0x6D140cEb8AdC42Af4BbC79BeDAe38D9bDbbAc922 |
| TokenBridge address          | 0x50749B80D19c275f4BdC25084Ef8961a739Ae5b3 |
----------------------------------------------------------------------------

#### Deploy the Core Shutdown contract

```shell
ethereum$ MNEMONIC=<redacted> ./sh/deployCoreShutdown.sh
```

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.

Transactions saved to: /workspace/wormhole/ethereum/broadcast/DeployCoreShutdown.s.sol/421614/run-latest.json

Sensitive values saved to: /workspace/wormhole/ethereum/cache/DeployCoreShutdown.s.sol/421614/run-latest.json

Wormhole Core Shutdown address: 0x97Bc042a1826F369Ef35199945066651cEa65f88

#### Deploy the TokenBridge Shutdown contract

```shell
ethereum$ MNEMONIC=<redacted> ./sh/deployTokenBridgeShutdown.sh
```

==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.

Transactions saved to: /workspace/wormhole/ethereum/broadcast/DeployTokenBridgeShutdown.s.sol/421614/run-latest.json

Sensitive values saved to: /workspace/wormhole/ethereum/cache/DeployTokenBridgeShutdown.s.sol/421614/run-latest.json

TokenBridge Shutdown address: 0x1B8E4482093cfeAAe78FEa7F2c66F17b33B26409

#### Deploy the Custom Consistency Level contract

```shell
ethereum$ RPC_URL= MNEMONIC= EVM_CHAIN_ID= ./sh/deployCustomConsistencyLevel.sh
```
==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.

Transactions saved to: /workspace/wormhole/ethereum/broadcast/DeployCustomConsistencyLevel.s.sol/421614/run-latest.json

Sensitive values saved to: /workspace/wormhole/ethereum/cache/DeployCustomConsistencyLevel.s.sol/421614/run-latest.json

Deployed custom consistency level to address: 0x6A4B4A882F5F0a447078b4Fd0b4B571A82371ec2

#### Generate Flattened Source

To generated the flattened source files to verify the contracts using the explorer UI

```shell
ethereum$ ./sh/flatten.sh
```

This will put the flattened files in `ethereum/flattened`.

#### Upgrade the Core or TokenBridge Implementation

```shell
ethereum$ MNEMONIC= ./sh/upgrade.sh testnet Core blast
ethereum$ MNEMONIC= ./sh/upgrade.sh testnet TokenBridge blast
```

#### Registering Other Chains on a New TokenBridge

```shell
ethereum$ MNEMONIC= ./sh/registerAllChainsOnTokenBridge.sh <network> <chainName> <tokenBridgeAddress>
```

### Testing

Run all ethereum tests using `make test`

### User methods

`submitVAA(bytes vaa)` can be used to execute a VAA.

`lockAssets(address asset, uint256 amount, bytes32 recipient, uint8 target_chain)` can be used
to transfer any ERC20 compliant asset out of ETH to any recipient on another chain that is connected to the Wormhole
protocol. `asset` is the asset to be transferred, `amount` is the amount to transfer (this must be <= the allowance that
you have previously given to the bridge smart contract if the token is not a wormhole token), `recipient` is the foreign
chain address of the recipient, `target_chain` is the id of the chain to transfer to.

`lockETH(bytes32 recipient, uint8 target_chain)` is a convenience function to wrap the Ether sent with the function call
and transfer it as described in `lockAssets`.

### Forge

Some tests and scripts use [Foundry](https://getfoundry.sh/). It can be installed via the official installer, or by running

```sh
wormhole/ethereum $ ../scripts/install-foundry
```

The installer script installs foundry and the appropriate solc version to build the contracts.
