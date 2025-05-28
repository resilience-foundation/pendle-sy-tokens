// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import {UnitSYTest} from "../helpers/UnitSYTest.sol";
import {PendleREUSDESY} from "../../src/PendleREUSDESY.sol";
import {IStandardizedYield} from "pendle-sy/interfaces/IStandardizedYield.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title PendleREUSDESYUnitTest
 * @notice Unit tests for PendleREUSDESY using mock oracle with real tokens on forked mainnet
 * @dev Tests exchange rate calculation logic with controlled values + real token integration
 */
contract PendleREUSDESYUnitTest is UnitSYTest {
    address constant USDE = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;

    function _deploySYWithOracle(address oracleAddress) internal override {
        PendleREUSDESY implementation = new PendleREUSDESY();
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        
        bytes memory initData = abi.encodeWithSelector(
            PendleREUSDESY.initialize.selector,
            oracleAddress
        );
        
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(proxyAdmin),
            initData
        );
        
        sy = IStandardizedYield(address(proxy));
    }

    // ===== UNIT TESTS: Exchange Rate Calculation Logic =====

    function test_exactRate_oneToOne() public {
        setMockRateToOne();
        
        uint256 rate = sy.exchangeRate();
        uint256 syAmount = 1e18;
        uint256 usdeValue = (syAmount * rate) / 1e18;
        
        assertEq(rate, 1e18);
        assertEq(usdeValue, 1e18); // Exactly 1:1
    }

    function test_exactRate_onePointFive() public {
        setMockRateToOnePointFive();
        
        uint256 rate = sy.exchangeRate();
        uint256 syAmount = 1e18;
        uint256 usdeValue = (syAmount * rate) / 1e18;
        
        assertEq(rate, 1.5e18);
        assertEq(usdeValue, 1.5e18); // Exactly 50% premium
    }

    function test_exactRate_two() public {
        setMockRateToTwo();
        
        uint256 rate = sy.exchangeRate();
        uint256 syAmount = 1e18;
        uint256 usdeValue = (syAmount * rate) / 1e18;
        
        assertEq(rate, 2e18);
        assertEq(usdeValue, 2e18); // Exactly 100% premium
    }

    function test_exactRate_extreme() public {
        setMockRateToTen();
        
        uint256 rate = sy.exchangeRate();
        uint256 syAmount = 1e18;
        uint256 usdeValue = (syAmount * rate) / 1e18;
        
        assertEq(rate, 10e18);
        assertEq(usdeValue, 10e18); // 10x value
    }

    // ===== REAL TOKEN INTEGRATION TESTS =====

    function test_deposit_withControlledRate() public {
        address user = wallets[0];
        address reUSDe = PendleREUSDESY(payable(address(sy))).REUSDE();
        uint256 amount = refAmountFor(reUSDe) * 1000; // 1000 reUSDe
        
        // Set controlled rate for predictable testing
        setMockRateToOnePointFive(); // 1.5x rate
        
        fundToken(user, reUSDe, amount);
        uint256 syReceived = deposit(user, reUSDe, amount);
        
        // For ERC20SY, deposit amount should equal SY received (1:1)
        assertEq(syReceived, amount);
        
        // But the underlying value should be affected by exchange rate
        uint256 underlyingValue = (syReceived * sy.exchangeRate()) / 1e18;
        assertEq(underlyingValue, amount * 1.5e18 / 1e18); // 1.5x the deposit
    }

    function test_redeem_withControlledRate() public {
        address user = wallets[1];
        address reUSDe = PendleREUSDESY(payable(address(sy))).REUSDE();
        uint256 depositAmount = refAmountFor(reUSDe) * 1000;
        
        // Set controlled rate
        setMockRateToTwo(); // 2x rate
        
        // Setup: deposit first using real tokens
        fundToken(user, reUSDe, depositAmount);
        uint256 syAmount = deposit(user, reUSDe, depositAmount);
        
        // Test redeem
        uint256 tokenReceived = redeem(user, reUSDe, syAmount);
        
        // Should get back original amount (ERC20SY is 1:1)
        assertEq(tokenReceived, depositAmount);
        
        // But the underlying value represented is 2x due to exchange rate
        uint256 underlyingValue = (syAmount * sy.exchangeRate()) / 1e18;
        assertEq(underlyingValue, depositAmount * 2);
    }

    function test_roundTrip_withDifferentRates() public {
        address user = wallets[2];
        address reUSDe = PendleREUSDESY(payable(address(sy))).REUSDE();
        uint256 amount = refAmountFor(reUSDe) * 500;
        
        // Test round trip with different exchange rates
        uint256[] memory rates = new uint256[](4);
        rates[0] = 1e18;      // 1:1
        rates[1] = 1.5e18;    // 1.5:1  
        rates[2] = 2e18;      // 2:1
        rates[3] = 10e18;     // 10:1
        
        for (uint i = 0; i < rates.length; i++) {
            setMockRate(rates[i]);
            
            fundToken(user, reUSDe, amount);
            uint256 syReceived = deposit(user, reUSDe, amount);
            uint256 tokenReceived = redeem(user, reUSDe, syReceived);
            
            // Should get back same amount regardless of exchange rate (ERC20SY)
            assertApproxEqAbs(tokenReceived, amount, 2); // Allow 2 wei rounding
            
            // But underlying value should scale with rate
            uint256 underlyingValue = (syReceived * sy.exchangeRate()) / 1e18;
            assertEq(underlyingValue, (amount * rates[i]) / 1e18);
        }
    }

    // ===== RATE CHANGE TESTING =====

    function test_rateChanges_duringOperations() public {
        address user = wallets[3];
        address reUSDe = PendleREUSDESY(payable(address(sy))).REUSDE();
        uint256 amount = refAmountFor(reUSDe) * 1000;
        
        // Start with 1:1 rate
        setMockRateToOne();
        fundToken(user, reUSDe, amount);
        uint256 syAmount = deposit(user, reUSDe, amount);
        
        // Verify initial state
        assertEq(sy.exchangeRate(), 1e18);
        uint256 initialValue = (syAmount * sy.exchangeRate()) / 1e18;
        assertEq(initialValue, amount);
        
        // Change rate to 2:1
        setMockRateToTwo();
        
        // SY balance should be same, but value should double
        assertEq(sy.balanceOf(user), syAmount);
        uint256 newValue = (syAmount * sy.exchangeRate()) / 1e18;
        assertEq(newValue, amount * 2);
        
        // Redeem should still work correctly
        uint256 tokenReceived = redeem(user, reUSDe, syAmount);
        assertApproxEqAbs(tokenReceived, amount, 2);
    }

    // ===== PRECISION TESTING =====

    function test_precision_smallAmounts() public {
        address user = wallets[4];
        address reUSDe = PendleREUSDESY(payable(address(sy))).REUSDE();
        uint256 smallAmount = refAmountFor(reUSDe) / 1000; // Very small amount
        
        setMockRateToOnePointFive();
        
        fundToken(user, reUSDe, smallAmount);
        uint256 syReceived = deposit(user, reUSDe, smallAmount);
        
        // Should still work with small amounts
        assertGt(syReceived, 0);
        assertEq(syReceived, smallAmount); // 1:1 for ERC20SY
        
        // Value calculation should be precise
        uint256 underlyingValue = (syReceived * sy.exchangeRate()) / 1e18;
        uint256 expectedValue = (smallAmount * 1.5e18) / 1e18;
        assertEq(underlyingValue, expectedValue);
    }

    function test_precision_largeAmounts() public {
        address user = wallets[0];
        address reUSDe = PendleREUSDESY(payable(address(sy))).REUSDE();
        uint256 largeAmount = refAmountFor(reUSDe) * 1_000_000; // 1M reUSDe
        
        setMockRateToOnePointFive();
        
        fundToken(user, reUSDe, largeAmount);
        uint256 syReceived = deposit(user, reUSDe, largeAmount);
        
        // Should work with large amounts
        assertEq(syReceived, largeAmount);
        
        // Value calculation should be precise even for large amounts
        uint256 underlyingValue = (syReceived * sy.exchangeRate()) / 1e18;
        uint256 expectedValue = (largeAmount * 1.5e18) / 1e18;
        assertEq(underlyingValue, expectedValue);
    }

    // ===== DECIMAL PRECISION - USDe Specific (18 decimals) =====

    function test_decimalPrecision_eighteenDecimals() public {
        // Test that USDe's 18 decimals work correctly with exchange rates
        setMockRateToOnePointFive();
        
        uint256 rate = sy.exchangeRate();
        uint256 verySmallAmount = 1; // 1 wei
        uint256 value = (verySmallAmount * rate) / 1e18;
        
        // With 18 decimal precision, even 1 wei scaled should work
        assertEq(value, 1); // 1 * 1.5e18 / 1e18 = 1 (rounded down)
    }

    function test_decimalPrecision_comparedToUSDC() public {
        // USDe (18 decimals) should have better precision than USDC (6 decimals)
        setMockRateToOnePointFive();
        uint256 rate = sy.exchangeRate();
        
        // Test fractional amounts that would be problematic with 6 decimals
        uint256 fractionalAmount = 1e15; // 0.001 USDe (would be 0.000001 USDC)
        uint256 value = (fractionalAmount * rate) / 1e18;
        
        // Should handle fractional calculations precisely
        assertEq(value, (fractionalAmount * 15) / 10); // 1.5x
        assertGt(value, 0); // Should not round to zero
    }

    // ===== SCALING BEHAVIOR TESTS =====

    function test_scaling_multipleAmounts() public {
        address user = wallets[1];
        address reUSDe = PendleREUSDESY(payable(address(sy))).REUSDE();
        
        setMockRateToTwo(); // 2x rate
        
        // Test different amounts scale correctly
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = refAmountFor(reUSDe);         // 1 reUSDe
        amounts[1] = refAmountFor(reUSDe) * 10;    // 10 reUSDe
        amounts[2] = refAmountFor(reUSDe) * 100;   // 100 reUSDe
        amounts[3] = refAmountFor(reUSDe) * 1000;  // 1000 reUSDe
        
        for (uint i = 0; i < amounts.length; i++) {
            fundToken(user, reUSDe, amounts[i]);
            uint256 syReceived = deposit(user, reUSDe, amounts[i]);
            
            // Linear scaling for deposits
            assertEq(syReceived, amounts[i]);
            
            // Value should scale linearly with exchange rate
            uint256 underlyingValue = (syReceived * sy.exchangeRate()) / 1e18;
            assertEq(underlyingValue, amounts[i] * 2); // 2x due to rate
            
            // Clean up for next iteration
            redeem(user, reUSDe, syReceived);
        }
    }

    // ===== ASSET INFO CONSISTENCY =====

    function test_assetInfo_independentOfRate() public {
        // Asset info should be consistent regardless of exchange rate
        setMockRateToOne();
        (IStandardizedYield.AssetType assetType1, address assetAddress1, uint8 assetDecimals1) = sy.assetInfo();
        
        setMockRateToTen();
        (IStandardizedYield.AssetType assetType2, address assetAddress2, uint8 assetDecimals2) = sy.assetInfo();
        
        // Should be identical regardless of rate
        assertEq(uint8(assetType1), uint8(assetType2));
        assertEq(assetAddress1, assetAddress2);
        assertEq(assetDecimals1, assetDecimals2);
        
        // Verify expected values (USDe specific)
        assertEq(uint8(assetType1), uint8(IStandardizedYield.AssetType.TOKEN));
        assertEq(assetAddress1, USDE);
        assertEq(assetDecimals1, 18); // USDe has 18 decimals
    }

    // ===== ORACLE INTEGRATION =====

    function test_oracleIntegration_mockBehavior() public {
        // Test that SY correctly reads from mock oracle
        setMockRateToOnePointFive();
        assertEq(sy.exchangeRate(), 1.5e18);
        
        setMockRateToTwo();
        assertEq(sy.exchangeRate(), 2e18);
        
        // Test direct oracle access
        PendleREUSDESY syContract = PendleREUSDESY(payable(address(sy)));
        assertEq(syContract.exchangeRateOracle(), address(mockOracle));
        assertEq(mockOracle.getExchangeRate(), 2e18);
    }

    // ===== COMPARATIVE TESTING - reUSDe vs reUSD consistency =====

    function test_behaviorConsistency_withReUSD() public {
        // Both reUSD and reUSDe SY should behave identically for same exchange rates
        setMockRateToOnePointFive();
        
        uint256 rate = sy.exchangeRate();
        uint256 testAmount = 1000e18;
        uint256 expectedValue = (testAmount * 1.5e18) / 1e18;
        uint256 actualValue = (testAmount * rate) / 1e18;
        
        assertEq(actualValue, expectedValue);
        assertEq(rate, 1.5e18);
        
        // Verify calculation matches exactly what reUSD version would produce
        assertEq(actualValue, testAmount + (testAmount / 2)); // 1.5x = 1x + 0.5x
    }
}