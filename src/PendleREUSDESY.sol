// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "pendle-sy/core/StandardizedYield/implementations/PendleERC20SYUpg.sol";

contract PendleREUSDESY is PendleERC20SYUpg {
    address public constant REUSDE = 0xdDC0f880ff6e4e22E4B74632fBb43Ce4DF6cCC5a;

    constructor() PendleERC20SYUpg(REUSDE) {}

    function initialize() external initializer {
        __SYBaseUpg_init("SY reUSDe", "SY-reUSDe");
    }
}