// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "pendle-sy/core/StandardizedYield/implementations/PendleERC20SYUpg.sol";
import "pendle-sy/interfaces/IPExchangeRateOracle.sol";
import "pendle-sy/core/libraries/Errors.sol";

contract PendleREUSDSY is PendleERC20SYUpg {
    address public constant REUSD = 0x5086bf358635B81D8C47C66d1C8b9E567Db70c72;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // Mainnet USDC
    
    address public exchangeRateOracle;
    
    event SetNewExchangeRateOracle(address oracle);

    constructor() PendleERC20SYUpg(REUSD) {}

    /// @notice Initializes the SY contract with an exchange rate oracle
    /// @param _exchangeRateOracle Address of the IPExchangeRateOracle contract
    function initialize(address _exchangeRateOracle) external initializer {
        __SYBaseUpg_init("SY reUSD", "SY-reUSD");
        if (_exchangeRateOracle == address(0)) revert Errors.ZeroAddress();
        exchangeRateOracle = _exchangeRateOracle;
    }
    
    /// @notice Returns the exchange rate between SY token and underlying asset
    /// @return Exchange rate scaled by 1e18 (1e18 = 1:1 ratio)
    function exchangeRate() public view virtual override returns (uint256) {
        return IPExchangeRateOracle(exchangeRateOracle).getExchangeRate();
    }
    
    /// @notice Updates the exchange rate oracle address
    /// @param newOracle Address of the new IPExchangeRateOracle contract
    /// @dev Only callable by contract owner
    function setExchangeRateOracle(address newOracle) external onlyOwner {
        if (newOracle == address(0)) revert Errors.ZeroAddress();
        exchangeRateOracle = newOracle;
        emit SetNewExchangeRateOracle(newOracle);
    }
    
    /// @notice Returns info about the underlying asset (USDC, not reUSD)
    /// @dev Since exchangeRate represents SY:USDC ratio, we return USDC as the asset
    function assetInfo() external view override returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        return (AssetType.TOKEN, USDC, IERC20Metadata(USDC).decimals());
    }
}