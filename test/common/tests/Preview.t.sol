// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import {console} from "forge-std/Test.sol";

import {TestFoundation} from "../TestFoundation.sol";

abstract contract PreviewTest is TestFoundation {
    function test_preview_depositThenRedeem() public {
        address[] memory allTokensIn = getTokensInForPreviewTest();
        address[] memory allTokensOut = getTokensOutForPreviewTest();

        address alice = wallets[0];

        uint256 snapshot = vm.snapshotState();
        for (uint256 i = 0; i < allTokensIn.length; ++i) {
            for (uint256 j = 0; j < allTokensOut.length; ++j) {
                vm.revertToState(snapshot);

                address tokenIn = allTokensIn[i];
                address tokenOut = allTokensOut[j];
                uint256 amountIn = refAmountFor(tokenIn);

                console.log("Testing", getSymbol(tokenIn), "=>", getSymbol(tokenOut));
                console.log("Amount in:", amountIn);

                fundToken(alice, tokenIn, amountIn);
                _executePreviewTest(alice, tokenIn, amountIn, tokenOut);
            }
        }
    }

    function _executePreviewTest(address wallet, address tokenIn, uint256 netTokenIn, address tokenOut) private {
        uint256 depositIn = netTokenIn / 2;
        for (uint256 i = 0; i < 2; ++i) {
            uint256 balanceBefore = sy.balanceOf(wallet);

            uint256 preview = sy.previewDeposit(tokenIn, depositIn);
            uint256 actual = deposit(wallet, tokenIn, depositIn);
            uint256 earning = sy.balanceOf(wallet) - balanceBefore;

            assertEq(earning, actual, "previewDeposit: actual != earning");
            assertEq(preview, actual, "previewDeposit: preview != actual");
        }

        uint256 redeemIn = sy.balanceOf(wallet) / 2;
        for (uint256 i = 0; i < 2; ++i) {
            uint256 balanceBefore = getBalance(wallet, tokenOut);

            uint256 preview = sy.previewRedeem(tokenOut, redeemIn);
            uint256 actual = redeem(wallet, tokenOut, redeemIn);
            uint256 earning = getBalance(wallet, tokenOut) - balanceBefore;

            assertEq(earning, actual, "previewRedeem: actual != earning");
            assertEq(preview, actual, "previewRedeem: preview != actual");
        }
    }

    function getTokensInForPreviewTest() internal view virtual returns (address[] memory) {
        return sy.getTokensIn();
    }

    function getTokensOutForPreviewTest() internal view virtual returns (address[] memory) {
        return sy.getTokensOut();
    }
}
