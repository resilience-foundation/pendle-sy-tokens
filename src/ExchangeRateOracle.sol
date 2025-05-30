// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IPExchangeRateOracle} from "pendle-sy/interfaces/IPExchangeRateOracle.sol";
import {ISharePriceCalculator} from "./interfaces/ISharePriceCalculator.sol";
import {IExchangeRateSource} from "./interfaces/IExchangeRateSource.sol";

error ZeroAddress();

contract ExchangeRateOracle is IPExchangeRateOracle {
      IExchangeRateSource public immutable EXCHANGE_RATE_SOURCE;

      constructor(address _exchangeRateSource) {
          if (_exchangeRateSource == address(0)) {
            revert ZeroAddress();
          }
          EXCHANGE_RATE_SOURCE = IExchangeRateSource(_exchangeRateSource);
      }

      function getExchangeRate() external view override returns (uint256) {
          return EXCHANGE_RATE_SOURCE.getSharePrice();
      }
  }
