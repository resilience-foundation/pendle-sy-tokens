# Pendle Standardized Yield (SY) Tokens for reUSD and reUSDe

## Introduction

This repository contains Pendle Standardized Yield (SY) token implementations for two yield-bearing stablecoins:
- **reUSD** (0x5086bf358635B81D8C47C66d1C8b9E567Db70c72)
- **reUSDe** (0xdDC0f880ff6e4e22E4B74632fBb43Ce4DF6cCC5a)

These SY wrappers enable reUSD and reUSDe tokens to be integrated with Pendle's yield trading protocol, allowing users to split their yield-bearing assets into Principal Tokens (PT) and Yield Tokens (YT).

The implementations use Pendle's `PendleERC20SYUpg` base contract, providing a simple 1:1 wrapper with upgradeable proxy pattern support.

## Getting started

### 1. Install Foundry

If already installed, skip this step. Else please visit [Foundry's installation guide](https://book.getfoundry.sh/getting-started/installation.html) to install Foundry.

### 2. Set up the environment

```bash
yarn install
forge install
```

### 3. Configure RPC URL

Copy the example environment file and add your Ethereum mainnet RPC URL:

```bash
cp .env.example .env
```

Edit `.env` and set your `ETH_RPC_URL`. You can get a free RPC URL from providers like [Alchemy](https://www.alchemy.com/), [Infura](https://infura.io/), or [Ankr](https://www.ankr.com/).

## Contract Overview

### Main Contracts

The repository includes two SY token implementations:

1. **PendleREUSDSY** (`src/PendleREUSDSY.sol`)
   - Wraps reUSD token
   - Contract address: 0x5086bf358635B81D8C47C66d1C8b9E567Db70c72
   - Symbol: SY-reUSD

2. **PendleREUSDESY** (`src/PendleREUSDESY.sol`)
   - Wraps reUSDe token
   - Contract address: 0xdDC0f880ff6e4e22E4B74632fBb43Ce4DF6cCC5a
   - Symbol: SY-reUSDe

Both contracts inherit from `PendleERC20SYUpg` which provides:
- 1:1 exchange rate with the underlying token
- Standard deposit/redeem functionality
- Upgradeable proxy pattern support
- ERC20 compliance

## Run the tests

To run the tests, you can use the following command:

```bash
forge test --match-contract [YOUR_CONTRACT_NAME] -vv
```

To better review the test results, please check all the lines starting with `[CHECK REQUIRED]` mark and see if the result is expected:

- **Preview**: This consists of depositing from a `tokenIn` and redeeming to a `tokenOut`. Please check if the according value of `tokenIn` and `tokenOut` are equivalent.

- **Metadata**: Please read all the lines to see if the metadata you put in is correct.

- **Rewards** (adapter can skip): Please check if all the yielding reward tokens are being distributed and claimed correctly.

## Deploy your implementation

For your own safety, we recommend you to move the tested implementation to your preferred place where you have better control over its security. To make this easier, you can use Foundry's flattening feature:

```bash
forge flatten [YOUR_IMPLEMENTATION_PATH] > flattened_contracts/[YOUR_CONTRACT_NAME].sol
```

## Links

- [Re Protocol Documentation](https://docs.re.xyz/)
- [Pendle Finance](https://pendle.finance)
- [Pendle Documentation](https://docs.pendle.finance/Developers/Overview)
