// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import {SYTest} from "../common/SYTest.t.sol";
import {PendleREUSDSY} from "../../src/PendleREUSDSY.sol";
import {IStandardizedYield} from "pendle-sy/interfaces/IStandardizedYield.sol";

contract PendleREUSDSYTest is SYTest {
    function setUpFork() internal override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    function deploySY() internal override {
        vm.startPrank(deployer);

        address reusdSY = address(new PendleREUSDSY());
        sy = IStandardizedYield(reusdSY);

        vm.stopPrank();
    }
}
