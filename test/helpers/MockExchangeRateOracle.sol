// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import {IPExchangeRateOracle} from "pendle-sy/interfaces/IPExchangeRateOracle.sol";

/**
 * @title MockExchangeRateOracle
 * @notice Mock oracle for testing exchange rate functionality with controlled values
 * @dev Implements IPExchangeRateOracle interface for deterministic testing
 */
contract MockExchangeRateOracle is IPExchangeRateOracle {
    uint256 private _exchangeRate;
    
    constructor(uint256 initialRate) {
        _exchangeRate = initialRate;
    }

    /// @notice Get the current exchange rate
    function getExchangeRate() external view override returns (uint256) {
        return _exchangeRate;
    }

    /// @notice Set a new exchange rate for testing
    function setExchangeRate(uint256 newRate) external {
        _exchangeRate = newRate;
    }

    // Convenience functions for common test scenarios
    
    /// @notice Set rate to 1:1 (no premium)
    function setRateToOne() external {
        _exchangeRate = 1e18;
    }

    /// @notice Set rate to 1.5:1 (50% premium)
    function setRateToOnePointFive() external {
        _exchangeRate = 1.5e18;
    }

    /// @notice Set rate to 2:1 (100% premium)
    function setRateToTwo() external {
        _exchangeRate = 2e18;
    }

    /// @notice Set rate to 10:1 (extreme scenario)
    function setRateToTen() external {
        _exchangeRate = 10e18;
    }

    /// @notice Set a very small premium for precision testing
    function setRateToMinimalPremium() external {
        _exchangeRate = 1.000001e18;
    }

    /// @notice Set a rate just below 2x for boundary testing
    function setRateToAlmostTwo() external {
        _exchangeRate = 1.999999e18;
    }
}