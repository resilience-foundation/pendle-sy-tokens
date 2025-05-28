// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import {SYTest} from "../common/SYTest.t.sol";
import {PendleREUSDESY} from "../../src/PendleREUSDESY.sol";
import {IStandardizedYield} from "pendle-sy/interfaces/IStandardizedYield.sol";

contract PendleREUSDESYTest is SYTest {
    function setUpFork() internal override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    function deploySY() internal override {
        vm.startPrank(deployer);

        address reusdeSY = address(new PendleREUSDESY());
        sy = IStandardizedYield(reusdeSY);

        vm.stopPrank();
    }
}
