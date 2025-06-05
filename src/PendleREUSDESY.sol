// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "pendle-sy/core/StandardizedYield/implementations/PendleERC20SYUpg.sol";
import "pendle-sy/interfaces/IPExchangeRateOracle.sol";
import "pendle-sy/core/libraries/Errors.sol";

contract PendleREUSDESY is PendleERC20SYUpg {
    address public constant REUSDE = 0xdDC0f880ff6e4e22E4B74632fBb43Ce4DF6cCC5a;
    address public constant USDE = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3; // Mainnet USDe
    
    address public exchangeRateOracle;
    
    event SetNewExchangeRateOracle(address oracle);

    constructor() PendleERC20SYUpg(REUSDE) {}

    /// @notice Initializes the SY contract with an exchange rate oracle
    /// @param _exchangeRateOracle Address of the IPExchangeRateOracle contract
    function initialize(address _exchangeRateOracle) external initializer {
        __SYBaseUpg_init("SY reUSDe", "SY-reUSDe");
        if (_exchangeRateOracle == address(0)) revert Errors.ZeroAddress();
        exchangeRateOracle = _exchangeRateOracle;
    }
    
    /// @notice Returns the exchange rate between SY token and underlying asset
    /// @return Exchange rate scaled by 1e18 (1e18 = 1:1 ratio)
    function exchangeRate() public view virtual override returns (uint256) {
        // No decimal adjustment needed: both SY and USDe have 18 decimals
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
    
    /// @notice Returns info about the underlying asset (USDe, not reUSDe)
    /// @dev Since exchangeRate represents SY:USDe ratio, we return USDe as the asset
    function assetInfo() external view override returns (AssetType assetType, address assetAddress, uint8 assetDecimals) {
        return (AssetType.TOKEN, USDE, IERC20Metadata(USDE).decimals());
    }
}