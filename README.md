# Pendle Standardized Yield (SY) Tokens for reUSD and reUSDe

## Introduction

This repository contains Pendle Standardized Yield (SY) token implementations for two yield-bearing stablecoins:
- **reUSD** (0x5086bf358635B81D8C47C66d1C8b9E567Db70c72)
- **reUSDe** (0xdDC0f880ff6e4e22E4B74632fBb43Ce4DF6cCC5a)

These SY wrappers enable reUSD and reUSDe tokens to be integrated with Pendle's yield trading protocol, allowing users to split their yield-bearing assets into Principal Tokens (PT) and Yield Tokens (YT).

## Architecture

### Exchange Rate Integration

Unlike standard SY implementations, these contracts integrate with **Re protocol share price oracles** to properly represent the yield-bearing nature of reUSD and reUSDe:

- **Exchange Rate Source**: External `IPExchangeRateOracle` contracts
- **Asset Mapping**: SY tokens represent underlying USDC/USDe value
- **Yield Tracking**: Exchange rates > 1e18 indicate accumulated yield

### Deployed Oracles

| Token | Oracle Address | Underlying Asset |
|-------|---------------|------------------|
| reUSD | `0x05175571FE251Be44511240CAF3Ac305A4B3fb1e` | USDC |
| reUSDe | `0x50437254FCF805B44C997B2Ee04f34704170BD3c` | USDe |

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

1. **PendleREUSDSY** (`src/PendleREUSDSY.sol`)
   - Wraps reUSD token with oracle-based exchange rates
   - Underlying asset: USDC
   - Symbol: SY-reUSD
   - Exchange rate reflects reUSD → USDC value

2. **PendleREUSDESY** (`src/PendleREUSDESY.sol`) 
   - Wraps reUSDe token with oracle-based exchange rates
   - Underlying asset: USDe
   - Symbol: SY-reUSDe
   - Exchange rate reflects reUSDe → USDe value

Both contracts inherit from `PendleERC20SYUpg` which provides:
- Oracle-based exchange rates (not 1:1)
- Standard deposit/redeem functionality
- Upgradeable proxy pattern support
- ERC20 compliance

## Testing Strategy

We use a **hybrid testing approach** for comprehensive coverage:

### Unit Tests (Controlled Exchange Rates)
- **Files**: `test/sy/*-unit.t.sol`
- **Oracle**: Mock oracle with controlled rates
- **Purpose**: Deterministic testing of exchange rate calculations
- **Coverage**: Exact scenarios (1x, 1.5x, 2x, 10x rates)

### Integration Tests (Real Exchange Rates)  
- **Files**: `test/sy/reusd.t.sol`, `test/sy/reusde.t.sol`
- **Oracle**: Real deployed oracles
- **Purpose**: Property-based validation with live data
- **Coverage**: Real token behavior and oracle connectivity

## Run the tests

### Run All Tests
```bash
forge test
```

### Run Specific Test Types
```bash
# Unit tests only (controlled exchange rates)
forge test --match-path "*unit.t.sol"

# Integration tests only (real exchange rates)  
forge test --match-path "test/sy/reusd.t.sol" --match-path "test/sy/reusde.t.sol"

# Specific contract tests
forge test --match-contract PendleREUSDSYTest -vv
```

### Test Results
```bash
# Expected results: 68 tests passed
# - 29 unit tests (controlled scenarios)
# - 39 integration tests (real oracle validation)
```

To better review the test results, please check all the lines starting with `[CHECK REQUIRED]` mark and see if the result is expected:

- **Exchange Rate**: Current oracle rate at test execution
- **Preview**: This consists of depositing from a `tokenIn` and redeeming to a `tokenOut`. Please check if the according value of `tokenIn` and `tokenOut` are equivalent.
- **Metadata**: Please read all the lines to see if the metadata you put in is correct.
- **Asset Info**: Verify underlying asset mapping (USDC/USDe, not reUSD/reUSDe)
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