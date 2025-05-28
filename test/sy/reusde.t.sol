// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import {SYTest} from "../common/SYTest.t.sol";
import {PendleREUSDESY} from "../../src/PendleREUSDESY.sol";
import {IStandardizedYield} from "pendle-sy/interfaces/IStandardizedYield.sol";
import {IPExchangeRateOracle} from "pendle-sy/interfaces/IPExchangeRateOracle.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PendleREUSDESYTest is SYTest {
    address constant REUSDE_ORACLE = 0x50437254FCF805B44C997B2Ee04f34704170BD3c;
    address constant USDE = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    
    function setUpFork() internal override {
        // Fork at block 22583896 for consistent exchange rate testing
        // At this block: reUSDe exchange rate = 1185945887340090112
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 22583896);
    }

    function deploySY() internal override {
        vm.startPrank(deployer);

        PendleREUSDESY implementation = new PendleREUSDESY();
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        
        bytes memory initData = abi.encodeWithSelector(
            PendleREUSDESY.initialize.selector,
            REUSDE_ORACLE
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
        PendleREUSDESY syContract = PendleREUSDESY(payable(address(sy)));
        assertEq(syContract.exchangeRateOracle(), REUSDE_ORACLE);
        
        uint256 rate = sy.exchangeRate();
        assertGt(rate, 0);
        
        uint256 oracleRate = IPExchangeRateOracle(REUSDE_ORACLE).getExchangeRate();
        assertEq(rate, oracleRate);
    }
    
    function test_assetInfo() public {
        (IStandardizedYield.AssetType assetType, address assetAddress, uint8 assetDecimals) = sy.assetInfo();
        
        assertEq(uint8(assetType), uint8(IStandardizedYield.AssetType.TOKEN));
        assertEq(assetAddress, USDE);
        assertEq(assetDecimals, 18); // USDe has 18 decimals
    }
    
    // Access Control & Security Tests
    function test_setExchangeRateOracle_onlyOwner() public {
        address attacker = wallets[0]; // alice as attacker
        address newOracle = makeAddr("newOracle");
        
        vm.prank(attacker);
        vm.expectRevert("Ownable: caller is not the owner");
        PendleREUSDESY(payable(address(sy))).setExchangeRateOracle(newOracle);
    }
    
    function test_setExchangeRateOracle_rejectsZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSignature("ZeroAddress()"));
        PendleREUSDESY(payable(address(sy))).setExchangeRateOracle(address(0));
    }
    
    function test_setExchangeRateOracle_emitsEvent() public {
        address newOracle = makeAddr("newOracle");
        
        vm.prank(deployer);
        vm.expectEmit(true, false, false, true);
        emit SetNewExchangeRateOracle(newOracle);
        PendleREUSDESY(payable(address(sy))).setExchangeRateOracle(newOracle);
        
        assertEq(PendleREUSDESY(payable(address(sy))).exchangeRateOracle(), newOracle);
    }
    
    // Real Token Integration Tests
    function test_deposit_withRealTokens() public {
        address user = wallets[0];
        address reUSDe = PendleREUSDESY(payable(address(sy))).REUSDE();
        uint256 amount = refAmountFor(reUSDe) * 1000;
        
        uint256 initialSyBalance = sy.balanceOf(user);
        uint256 initialTokenBalance = getBalance(user, reUSDe);
        
        fundToken(user, reUSDe, amount);
        uint256 syReceived = deposit(user, reUSDe, amount);
        
        assertEq(sy.balanceOf(user), initialSyBalance + syReceived);
        assertEq(getBalance(user, reUSDe), initialTokenBalance); // Should be 0 after deposit
        assertGt(syReceived, 0);
    }
    
    function test_redeem_withRealTokens() public {
        address user = wallets[1];
        address reUSDe = PendleREUSDESY(payable(address(sy))).REUSDE();
        uint256 depositAmount = refAmountFor(reUSDe) * 1000;
        
        // Setup: deposit first
        fundToken(user, reUSDe, depositAmount);
        uint256 syAmount = deposit(user, reUSDe, depositAmount);
        
        uint256 initialSyBalance = sy.balanceOf(user);
        uint256 initialTokenBalance = getBalance(user, reUSDe);
        
        uint256 tokenReceived = redeem(user, reUSDe, syAmount);
        
        assertEq(sy.balanceOf(user), initialSyBalance - syAmount);
        assertEq(getBalance(user, reUSDe), initialTokenBalance + tokenReceived);
        assertGt(tokenReceived, 0);
    }
    
    // Decimal Precision & Math Tests
    function test_exchangeRateConversion_toUSDe() public {
        // Test that exchange rate correctly converts SY to USDe value
        uint256 rate = sy.exchangeRate();
        uint256 syAmount = 1e18;
        
        // At block 22583896, rate should be exactly 1185945887340090112
        assertEq(rate, 1185945887340090112);
        
        uint256 usdeValue = (syAmount * rate) / 1e18;
        
        // Should be exactly 1185945887340090112 (≈ 1.186 USDe)
        assertEq(usdeValue, 1185945887340090112);
    }
    
    function test_deposit_smallAmount() public {
        address user = wallets[2];
        address reUSDe = PendleREUSDESY(payable(address(sy))).REUSDE();
        uint256 amount = refAmountFor(reUSDe) / 1000; // very small amount
        
        fundToken(user, reUSDe, amount);
        uint256 syReceived = deposit(user, reUSDe, amount);
        
        assertGt(syReceived, 0);
    }
    
    function test_deposit_largeAmount() public {
        address user = wallets[3];
        address reUSDe = PendleREUSDESY(payable(address(sy))).REUSDE();
        uint256 amount = refAmountFor(reUSDe) * 1_000_000;
        
        fundToken(user, reUSDe, amount);
        uint256 syReceived = deposit(user, reUSDe, amount);
        
        assertGt(syReceived, 0);
        // For ERC20SY, deposit returns 1:1, so syReceived should equal amount
        assertEq(syReceived, amount);
    }
    
    function test_roundTrip_noLoss() public {
        address user = wallets[4];
        address reUSDe = PendleREUSDESY(payable(address(sy))).REUSDE();
        uint256 amount = refAmountFor(reUSDe) * 1000;
        
        fundToken(user, reUSDe, amount);
        uint256 syReceived = deposit(user, reUSDe, amount);
        
        // Immediately redeem
        uint256 tokenReceived = redeem(user, reUSDe, syReceived);
        
        assertApproxEqAbs(tokenReceived, amount, 2); // Allow 2 wei difference for rounding
    }
    
    function test_exchangeRate_affectsDepositAmount() public {
        // Test that exchange rate affects SY token value correctly
        address user = wallets[0];
        address reUSDe = PendleREUSDESY(payable(address(sy))).REUSDE();
        uint256 amount = refAmountFor(reUSDe) * 1000;
        
        uint256 currentRate = sy.exchangeRate();
        assertEq(currentRate, 1185945887340090112); // Exact rate at block 22583896
        
        // Since this is ERC20SY, deposit returns amount directly (not affected by rate)
        // But the value of SY tokens is affected by the rate
        fundToken(user, reUSDe, amount);
        uint256 syReceived = deposit(user, reUSDe, amount);
        
        // For ERC20SY, syReceived should equal amount deposited
        assertEq(syReceived, amount);
        
        // But the value in USDe terms should be affected by exchange rate
        uint256 valueInUSDe = (syReceived * currentRate) / 1e18;
        
        // Should be worth ~18.59% more USDe due to exchange rate
        assertEq(valueInUSDe, (amount * 1185945887340090112) / 1e18);
    }
    
    event SetNewExchangeRateOracle(address oracle);
}
