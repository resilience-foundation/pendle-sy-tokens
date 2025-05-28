// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "pendle-sy/core/StandardizedYield/implementations/PendleERC20SYUpg.sol";

contract PendleREUSDSY is PendleERC20SYUpg {
    address public constant REUSD = 0x5086bf358635B81D8C47C66d1C8b9E567Db70c72;

    constructor() PendleERC20SYUpg(REUSD) {}

    function initialize() external initializer {
        __SYBaseUpg_init("SY reUSD", "SY-reUSD");
    }
}