// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/ISharePriceCalculator.sol";
import "./interfaces/IExchangeRateSource.sol";

/// @title SharePriceCalculator
/// @notice Handles conversion between token amounts and shares based on current share price
/// @dev Uses price oracles to determine token values and maintains a global share price
contract SharePriceCalculator is ISharePriceCalculator, IExchangeRateSource, AccessControl {

  error ZeroAddress();
  error InvalidPrice();

  bytes32 public constant PRICE_SETTER_ROLE = keccak256("PRICE_SETTER_ROLE");

  uint256 private sharePrice;

  /// @notice Initializes the SharePriceCalculator
  /// @param _initialSharePrice Initial share price value (scaled by 1e18)
  /// @param _admin Address with DEFAULT_ADMIN_ROLE
  /// @param _priceSetter Address with PRICE_SETTER_ROLE
  /// @dev Sets initial share price to 1e18 (1:1 ratio)
  constructor(
    uint256 _initialSharePrice,
    address _admin,
    address _priceSetter
  ) {
    if (_initialSharePrice == 0) revert InvalidPrice();
    if (_admin == address(0)) revert ZeroAddress();
    if (_priceSetter == address(0)) revert ZeroAddress();

    sharePrice = _initialSharePrice;

    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    _grantRole(PRICE_SETTER_ROLE, _priceSetter);
  }

  /// @notice Updates the global share price
  /// @param newPrice New share price value (scaled by 1e18)
  /// @dev Only callable by addresses with PRICE_SETTER_ROLE
  /// @dev Emits SharePriceSet event
  function setSharePrice(
    uint256 newPrice
  ) external onlyRole(PRICE_SETTER_ROLE) {
    if (newPrice < sharePrice) revert InvalidPrice(); // monotonic increasing
    uint256 oldPrice = sharePrice;
    sharePrice = newPrice;
    emit SharePriceSet(oldPrice, newPrice);
  }

  /// @notice Returns the current share price
  /// @return Current share price scaled by 1e18
  function getSharePrice() external view override(ISharePriceCalculator, IExchangeRateSource) returns (uint256) {
    return sharePrice;
  }
}
