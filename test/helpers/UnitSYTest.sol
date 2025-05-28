// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import {TestFoundation} from "../common/TestFoundation.sol";
import {MockExchangeRateOracle} from "./MockExchangeRateOracle.sol";
import {IStandardizedYield} from "pendle-sy/interfaces/IStandardizedYield.sol";

/**
 * @title UnitSYTest
 * @notice Base test class for unit tests with controlled exchange rates on forked mainnet
 * @dev Forks mainnet for real tokens but uses mock oracle for deterministic testing
 */
abstract contract UnitSYTest is TestFoundation {
    MockExchangeRateOracle mockOracle;
    bool usingMockOracle;

    function setUpFork() internal virtual override {
        // Fork mainnet for real tokens
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    /// @notice Deploy SY with mock oracle - calls deploySYWithMockOracle by default
    function deploySY() internal virtual override {
        // Deploy with 1:1 rate by default for unit tests
        deploySYWithMockOracle(1e18);
    }

    /// @notice Deploy SY with mock oracle set to specified rate
    function deploySYWithMockOracle(uint256 initialRate) internal {
        vm.startPrank(deployer);

        // Deploy mock oracle
        mockOracle = new MockExchangeRateOracle(initialRate);
        usingMockOracle = true;

        // Deploy SY with mock oracle
        _deploySYWithOracle(address(mockOracle));

        vm.stopPrank();
    }

    /// @notice Internal function to deploy SY with specified oracle
    /// @dev Must be implemented by concrete test contracts
    function _deploySYWithOracle(address oracleAddress) internal virtual;

    /// @notice Helper to change mock oracle rate during tests
    function setMockRate(uint256 newRate) internal {
        require(usingMockOracle, "Not using mock oracle");
        mockOracle.setExchangeRate(newRate);
    }

    /// @notice Helper functions for common rate scenarios
    function setMockRateToOne() internal {
        require(usingMockOracle, "Not using mock oracle");
        mockOracle.setRateToOne();
    }

    function setMockRateToOnePointFive() internal {
        require(usingMockOracle, "Not using mock oracle");
        mockOracle.setRateToOnePointFive();
    }

    function setMockRateToTwo() internal {
        require(usingMockOracle, "Not using mock oracle");
        mockOracle.setRateToTwo();
    }

    function setMockRateToTen() internal {
        require(usingMockOracle, "Not using mock oracle");
        mockOracle.setRateToTen();
    }
}