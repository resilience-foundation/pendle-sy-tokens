// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import {SYTest} from "../common/SYTest.t.sol";
import {PendleREUSDSY} from "../../src/PendleREUSDSY.sol";
import {IStandardizedYield} from "pendle-sy/interfaces/IStandardizedYield.sol";
import {IPExchangeRateOracle} from "pendle-sy/interfaces/IPExchangeRateOracle.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PendleREUSDSYTest is SYTest {
    address constant REUSD_ORACLE = 0x05175571FE251Be44511240CAF3Ac305A4B3fb1e;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    
    function setUpFork() internal override {
        // Fork at block 22583896 for consistent exchange rate testing
        // At this block: reUSD exchange rate = 1001046076164383616
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 22583896);
    }

    function deploySY() internal override {
        vm.startPrank(deployer);

        PendleREUSDSY implementation = new PendleREUSDSY();
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        
        bytes memory initData = abi.encodeWithSelector(
            PendleREUSDSY.initialize.selector,
            REUSD_ORACLE
        );
        
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(proxyAdmin),
            initData
        );
        
        sy = IStandardizedYield(address(proxy));

        vm.stopPrank();
    }
    
    function test_oracleIntegration() public {
        PendleREUSDSY syContract = PendleREUSDSY(payable(address(sy)));
        assertEq(syContract.exchangeRateOracle(), REUSD_ORACLE);
        
        uint256 rate = sy.exchangeRate();
        assertGt(rate, 0);
        
        uint256 oracleRate = IPExchangeRateOracle(REUSD_ORACLE).getExchangeRate();
        assertEq(rate, oracleRate);
    }
    
    function test_assetInfo() public {
        (IStandardizedYield.AssetType assetType, address assetAddress, uint8 assetDecimals) = sy.assetInfo();
        
        assertEq(uint8(assetType), uint8(IStandardizedYield.AssetType.TOKEN));
        assertEq(assetAddress, USDC);
        assertEq(assetDecimals, 6); // USDC has 6 decimals
    }
    
    // Access Control & Security Tests
    function test_setExchangeRateOracle_onlyOwner() public {
        address attacker = wallets[0]; // alice as attacker
        address newOracle = makeAddr("newOracle");
        
        vm.prank(attacker);
        vm.expectRevert("Ownable: caller is not the owner");
        PendleREUSDSY(payable(address(sy))).setExchangeRateOracle(newOracle);
    }
    
    function test_setExchangeRateOracle_rejectsZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSignature("ZeroAddress()"));
        PendleREUSDSY(payable(address(sy))).setExchangeRateOracle(address(0));
    }
    
    function test_setExchangeRateOracle_emitsEvent() public {
        address newOracle = makeAddr("newOracle");
        
        vm.prank(deployer);
        vm.expectEmit(true, false, false, true);
        emit SetNewExchangeRateOracle(newOracle);
        PendleREUSDSY(payable(address(sy))).setExchangeRateOracle(newOracle);
        
        assertEq(PendleREUSDSY(payable(address(sy))).exchangeRateOracle(), newOracle);
    }
    
    // Real Token Integration Tests
    function test_deposit_withRealTokens() public {
        address user = wallets[0];
        address reUSD = PendleREUSDSY(payable(address(sy))).REUSD();
        uint256 amount = refAmountFor(reUSD) * 1000;
        
        uint256 initialSyBalance = sy.balanceOf(user);
        uint256 initialTokenBalance = getBalance(user, reUSD);
        
        fundToken(user, reUSD, amount);
        uint256 syReceived = deposit(user, reUSD, amount);
        
        assertEq(sy.balanceOf(user), initialSyBalance + syReceived);
        assertEq(getBalance(user, reUSD), initialTokenBalance); // Should be 0 after deposit
        assertGt(syReceived, 0);
    }
    
    function test_redeem_withRealTokens() public {
        address user = wallets[1];
        address reUSD = PendleREUSDSY(payable(address(sy))).REUSD();
        uint256 depositAmount = refAmountFor(reUSD) * 1000;
        
        // Setup: deposit first
        fundToken(user, reUSD, depositAmount);
        uint256 syAmount = deposit(user, reUSD, depositAmount);
        
        uint256 initialSyBalance = sy.balanceOf(user);
        uint256 initialTokenBalance = getBalance(user, reUSD);
        
        uint256 tokenReceived = redeem(user, reUSD, syAmount);
        
        assertEq(sy.balanceOf(user), initialSyBalance - syAmount);
        assertEq(getBalance(user, reUSD), initialTokenBalance + tokenReceived);
        assertGt(tokenReceived, 0);
    }
    
    // Decimal Precision & Math Tests
    function test_exchangeRateConversion_toUSDC() public {
        // Test that exchange rate correctly converts SY to USDC value
        uint256 rate = sy.exchangeRate();
        uint256 syAmount = 1e18;
        
        // At block 22583896, rate should be exactly 1001046076164383616
        assertEq(rate, 1001046076164383616);
        
        // Calculate USDC value (accounting for 6 decimals)
        uint256 usdcValue = (syAmount * rate) / 1e18;
        
        // Should be exactly 1001046076164383616 (≈ 1.001046 USDC in 18 decimals)
        assertEq(usdcValue, 1001046076164383616);
    }
    
    function test_deposit_smallAmount() public {
        address user = wallets[2];
        address reUSD = PendleREUSDSY(payable(address(sy))).REUSD();
        uint256 amount = refAmountFor(reUSD) / 1000; // very small amount
        
        fundToken(user, reUSD, amount);
        uint256 syReceived = deposit(user, reUSD, amount);
        
        assertGt(syReceived, 0);
    }
    
    function test_deposit_largeAmount() public {
        address user = wallets[3];
        address reUSD = PendleREUSDSY(payable(address(sy))).REUSD();
        uint256 amount = refAmountFor(reUSD) * 1_000_000;
        
        fundToken(user, reUSD, amount);
        uint256 syReceived = deposit(user, reUSD, amount);
        
        assertGt(syReceived, 0);
        // For ERC20SY, deposit returns 1:1, so syReceived should equal amount
        assertEq(syReceived, amount);
    }
    
    function test_roundTrip_noLoss() public {
        address user = wallets[4];
        address reUSD = PendleREUSDSY(payable(address(sy))).REUSD();
        uint256 amount = refAmountFor(reUSD) * 1000;
        
        fundToken(user, reUSD, amount);
        uint256 syReceived = deposit(user, reUSD, amount);
        
        // Immediately redeem
        uint256 tokenReceived = redeem(user, reUSD, syReceived);
        
        assertApproxEqAbs(tokenReceived, amount, 2); // Allow 2 wei difference for rounding
    }
    
    event SetNewExchangeRateOracle(address oracle);
}
