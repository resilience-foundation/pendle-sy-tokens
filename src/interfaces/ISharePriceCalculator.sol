// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISharePriceCalculator {
  event SharePriceSet(uint256 oldPrice, uint256 newPrice);

  function setSharePrice(uint256 newPrice) external;

  function getSharePrice() external view returns (uint256);
}
