// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import {UnitSYTest} from "../helpers/UnitSYTest.sol";
import {PendleREUSDSY} from "../../src/PendleREUSDSY.sol";
import {IStandardizedYield} from "pendle-sy/interfaces/IStandardizedYield.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title PendleREUSDSYUnitTest
 * @notice Unit tests for PendleREUSDSY using mock oracle with real tokens on forked mainnet
 * @dev Tests exchange rate calculation logic with controlled values + real token integration
 */
contract PendleREUSDSYUnitTest is UnitSYTest {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function _deploySYWithOracle(address oracleAddress) internal override {
        PendleREUSDSY implementation = new PendleREUSDSY();
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        
        bytes memory initData = abi.encodeWithSelector(
            PendleREUSDSY.initialize.selector,
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
        uint256 usdcValue = (syAmount * rate) / 1e18;
        
        assertEq(rate, 1e18);
        assertEq(usdcValue, 1e18); // Exactly 1:1
    }

    function test_exactRate_onePointFive() public {
        setMockRateToOnePointFive();
        
        uint256 rate = sy.exchangeRate();
        uint256 syAmount = 1e18;
        uint256 usdcValue = (syAmount * rate) / 1e18;
        
        assertEq(rate, 1.5e18);
        assertEq(usdcValue, 1.5e18); // Exactly 50% premium
    }

    function test_exactRate_two() public {
        setMockRateToTwo();
        
        uint256 rate = sy.exchangeRate();
        uint256 syAmount = 1e18;
        uint256 usdcValue = (syAmount * rate) / 1e18;
        
        assertEq(rate, 2e18);
        assertEq(usdcValue, 2e18); // Exactly 100% premium
    }

    function test_exactRate_extreme() public {
        setMockRateToTen();
        
        uint256 rate = sy.exchangeRate();
        uint256 syAmount = 1e18;
        uint256 usdcValue = (syAmount * rate) / 1e18;
        
        assertEq(rate, 10e18);
        assertEq(usdcValue, 10e18); // 10x value
    }

    // ===== REAL TOKEN INTEGRATION TESTS =====

    function test_deposit_withControlledRate() public {
        address user = wallets[0];
        address reUSD = PendleREUSDSY(payable(address(sy))).REUSD();
        uint256 amount = refAmountFor(reUSD) * 1000; // 1000 reUSD
        
        // Set controlled rate for predictable testing
        setMockRateToOnePointFive(); // 1.5x rate
        
        fundToken(user, reUSD, amount);
        uint256 syReceived = deposit(user, reUSD, amount);
        
        // For ERC20SY, deposit amount should equal SY received (1:1)
        assertEq(syReceived, amount);
        
        // But the underlying value should be affected by exchange rate
        uint256 underlyingValue = (syReceived * sy.exchangeRate()) / 1e18;
        assertEq(underlyingValue, amount * 1.5e18 / 1e18); // 1.5x the deposit
    }

    function test_redeem_withControlledRate() public {
        address user = wallets[1];
        address reUSD = PendleREUSDSY(payable(address(sy))).REUSD();
        uint256 depositAmount = refAmountFor(reUSD) * 1000;
        
        // Set controlled rate
        setMockRateToTwo(); // 2x rate
        
        // Setup: deposit first using real tokens
        fundToken(user, reUSD, depositAmount);
        uint256 syAmount = deposit(user, reUSD, depositAmount);
        
        // Test redeem
        uint256 tokenReceived = redeem(user, reUSD, syAmount);
        
        // Should get back original amount (ERC20SY is 1:1)
        assertEq(tokenReceived, depositAmount);
        
        // But the underlying value represented is 2x due to exchange rate
        uint256 underlyingValue = (syAmount * sy.exchangeRate()) / 1e18;
        assertEq(underlyingValue, depositAmount * 2);
    }

    function test_roundTrip_withDifferentRates() public {
        address user = wallets[2];
        address reUSD = PendleREUSDSY(payable(address(sy))).REUSD();
        uint256 amount = refAmountFor(reUSD) * 500;
        
        // Test round trip with different exchange rates
        uint256[] memory rates = new uint256[](4);
        rates[0] = 1e18;      // 1:1
        rates[1] = 1.5e18;    // 1.5:1  
        rates[2] = 2e18;      // 2:1
        rates[3] = 10e18;     // 10:1
        
        for (uint i = 0; i < rates.length; i++) {
            setMockRate(rates[i]);
            
            fundToken(user, reUSD, amount);
            uint256 syReceived = deposit(user, reUSD, amount);
            uint256 tokenReceived = redeem(user, reUSD, syReceived);
            
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
        address reUSD = PendleREUSDSY(payable(address(sy))).REUSD();
        uint256 amount = refAmountFor(reUSD) * 1000;
        
        // Start with 1:1 rate
        setMockRateToOne();
        fundToken(user, reUSD, amount);
        uint256 syAmount = deposit(user, reUSD, amount);
        
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
        uint256 tokenReceived = redeem(user, reUSD, syAmount);
        assertApproxEqAbs(tokenReceived, amount, 2);
    }

    // ===== PRECISION TESTING =====

    function test_precision_smallAmounts() public {
        address user = wallets[4];
        address reUSD = PendleREUSDSY(payable(address(sy))).REUSD();
        uint256 smallAmount = refAmountFor(reUSD) / 1000; // Very small amount
        
        setMockRateToOnePointFive();
        
        fundToken(user, reUSD, smallAmount);
        uint256 syReceived = deposit(user, reUSD, smallAmount);
        
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
        address reUSD = PendleREUSDSY(payable(address(sy))).REUSD();
        uint256 largeAmount = refAmountFor(reUSD) * 1_000_000; // 1M reUSD
        
        setMockRateToOnePointFive();
        
        fundToken(user, reUSD, largeAmount);
        uint256 syReceived = deposit(user, reUSD, largeAmount);
        
        // Should work with large amounts
        assertEq(syReceived, largeAmount);
        
        // Value calculation should be precise even for large amounts
        uint256 underlyingValue = (syReceived * sy.exchangeRate()) / 1e18;
        uint256 expectedValue = (largeAmount * 1.5e18) / 1e18;
        assertEq(underlyingValue, expectedValue);
    }

    // ===== SCALING BEHAVIOR TESTS =====

    function test_scaling_multipleAmounts() public {
        address user = wallets[1];
        address reUSD = PendleREUSDSY(payable(address(sy))).REUSD();
        
        setMockRateToTwo(); // 2x rate
        
        // Test different amounts scale correctly
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = refAmountFor(reUSD);         // 1 reUSD
        amounts[1] = refAmountFor(reUSD) * 10;    // 10 reUSD
        amounts[2] = refAmountFor(reUSD) * 100;   // 100 reUSD
        amounts[3] = refAmountFor(reUSD) * 1000;  // 1000 reUSD
        
        for (uint i = 0; i < amounts.length; i++) {
            fundToken(user, reUSD, amounts[i]);
            uint256 syReceived = deposit(user, reUSD, amounts[i]);
            
            // Linear scaling for deposits
            assertEq(syReceived, amounts[i]);
            
            // Value should scale linearly with exchange rate
            uint256 underlyingValue = (syReceived * sy.exchangeRate()) / 1e18;
            assertEq(underlyingValue, amounts[i] * 2); // 2x due to rate
            
            // Clean up for next iteration
            redeem(user, reUSD, syReceived);
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
        
        // Verify expected values
        assertEq(uint8(assetType1), uint8(IStandardizedYield.AssetType.TOKEN));
        assertEq(assetAddress1, USDC);
        assertEq(assetDecimals1, 6); // USDC has 6 decimals
    }

    // ===== ORACLE INTEGRATION =====

    function test_oracleIntegration_mockBehavior() public {
        // Test that SY correctly reads from mock oracle
        setMockRateToOnePointFive();
        assertEq(sy.exchangeRate(), 1.5e18);
        
        setMockRateToTwo();
        assertEq(sy.exchangeRate(), 2e18);
        
        // Test direct oracle access
        PendleREUSDSY syContract = PendleREUSDSY(payable(address(sy)));
        assertEq(syContract.exchangeRateOracle(), address(mockOracle));
        assertEq(mockOracle.getExchangeRate(), 2e18);
    }
}