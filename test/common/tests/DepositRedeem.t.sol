// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import {console} from "forge-std/Test.sol";
import {PMath} from "pendle-sy/core/libraries/math/PMath.sol";

import {TestFoundation} from "../TestFoundation.sol";

abstract contract DepositRedeemTest is TestFoundation {
    using PMath for uint256;

    // function test_depositRedeem_exchangeRate() public {
    //     uint256 snapshot = vm.snapshotState();

    //     address[] memory tokensIn = getTokensInForDepositRedeemTest();
    //     for (uint256 k = 0; k < tokensIn.length; ++k) {
    //         vm.revertToState(snapshot);

    //         address tokenIn = tokensIn[k];

    //         uint256 n = wallets.length;
    //         uint256 refAmount = refAmountFor(tokenIn);
    //         for (uint256 i = 0; i < n; ++i) {
    //             uint256 expectedSyBalance = getExpectedSyOut(tokenIn, refAmount);

    //             fundToken(wallets[i], tokenIn, refAmount);
    //             deposit(wallets[i], tokenIn, refAmount);
    //             assertApproxEqRel(sy.balanceOf(wallets[i]), expectedSyBalance, 1e8);
    //         }
    //     }
    // }

    // function getTokensInForDepositRedeemTest() internal view virtual returns (address[] memory);

    // function getExpectedSyOut(address tokenIn, uint256 amountIn) internal view virtual returns (uint256);
}
