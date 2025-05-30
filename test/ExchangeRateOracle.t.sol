// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {ExchangeRateOracle, ZeroAddress} from "../src/ExchangeRateOracle.sol";
import {SharePriceCalculator} from "../src/SharePriceCalculator.sol";
import {IPExchangeRateOracle} from "pendle-sy/interfaces/IPExchangeRateOracle.sol";
import {IExchangeRateSource} from "../src/interfaces/IExchangeRateSource.sol";

/**
 * @title ExchangeRateOracleTest
 * @notice Comprehensive test suite for ExchangeRateOracle contract
 * @dev Tests constructor, oracle functionality, integration, and edge cases
 */
contract ExchangeRateOracleTest is Test {
    ExchangeRateOracle oracle;
    SharePriceCalculator calculator;
    MockExchangeRateSource mockSource;
    
    address admin;
    address priceSetter;
    address alice;
    
    uint256 constant INITIAL_PRICE = 1e18;
    uint256 constant UPDATED_PRICE = 2e18;
    
    function setUp() public {
        admin = address(0x3001);
        priceSetter = address(0x3002);
        alice = address(0x3003);
        
        // Deploy SharePriceCalculator for integration tests
        calculator = new SharePriceCalculator(INITIAL_PRICE, admin, priceSetter);
        
        // Deploy mock source for isolated tests
        mockSource = new MockExchangeRateSource(INITIAL_PRICE);
        
        // Deploy oracle with calculator as source
        oracle = new ExchangeRateOracle(address(calculator));
    }
    
    // ===== CONSTRUCTOR TESTS =====
    
    function test_constructor_success_withValidSource() public {
        ExchangeRateOracle newOracle = new ExchangeRateOracle(address(calculator));
        
        assertEq(address(newOracle.EXCHANGE_RATE_SOURCE()), address(calculator));
    }
    
    function test_constructor_success_withMockSource() public {
        ExchangeRateOracle newOracle = new ExchangeRateOracle(address(mockSource));
        
        assertEq(address(newOracle.EXCHANGE_RATE_SOURCE()), address(mockSource));
    }
    
    function test_constructor_setsSourceCorrectly() public view {
        assertEq(address(oracle.EXCHANGE_RATE_SOURCE()), address(calculator));
    }
    
    function test_constructor_revert_zeroSourceAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        new ExchangeRateOracle(address(0));
    }
    
    // ===== getExchangeRate FUNCTIONALITY TESTS =====
    
    function test_getExchangeRate_returnsSourcePrice() public view {
        uint256 rate = oracle.getExchangeRate();
        uint256 sourcePrice = calculator.getSharePrice();
        
        assertEq(rate, sourcePrice);
        assertEq(rate, INITIAL_PRICE);
    }
    
    function test_getExchangeRate_updatesWithSourceChanges() public {
        // Initial rate should be INITIAL_PRICE
        assertEq(oracle.getExchangeRate(), INITIAL_PRICE);
        
        // Update source price
        vm.prank(priceSetter);
        calculator.setSharePrice(UPDATED_PRICE);
        
        // Oracle should reflect the change
        assertEq(oracle.getExchangeRate(), UPDATED_PRICE);
    }
    
    function test_getExchangeRate_multipleCallsSameResult() public view {
        uint256 rate1 = oracle.getExchangeRate();
        uint256 rate2 = oracle.getExchangeRate();
        uint256 rate3 = oracle.getExchangeRate();
        
        assertEq(rate1, rate2);
        assertEq(rate2, rate3);
        assertEq(rate1, INITIAL_PRICE);
    }
    
    function test_getExchangeRate_publicAccess() public {
        // Should be callable by anyone
        oracle.getExchangeRate();
        
        vm.prank(alice);
        oracle.getExchangeRate();
        
        vm.prank(admin);
        oracle.getExchangeRate();
    }
    
    // ===== INTEGRATION TESTS WITH SharePriceCalculator =====
    
    function test_integration_withSharePriceCalculator() public view {
        // Oracle should work correctly with SharePriceCalculator
        uint256 oracleRate = oracle.getExchangeRate();
        uint256 calculatorPrice = calculator.getSharePrice();
        
        assertEq(oracleRate, calculatorPrice);
    }
    
    function test_integration_priceUpdatesReflected() public {
        uint256[] memory prices = new uint256[](5);
        prices[0] = 1.5e18;
        prices[1] = 2.0e18;
        prices[2] = 2.5e18;
        prices[3] = 3.0e18;
        prices[4] = 5.0e18;
        
        for (uint256 i = 0; i < prices.length; i++) {
            vm.prank(priceSetter);
            calculator.setSharePrice(prices[i]);
            
            assertEq(oracle.getExchangeRate(), prices[i]);
        }
    }
    
    function test_integration_multipleOracles() public {
        // Deploy multiple oracles using same calculator
        ExchangeRateOracle oracle2 = new ExchangeRateOracle(address(calculator));
        ExchangeRateOracle oracle3 = new ExchangeRateOracle(address(calculator));
        
        // All should return same initial value
        assertEq(oracle.getExchangeRate(), INITIAL_PRICE);
        assertEq(oracle2.getExchangeRate(), INITIAL_PRICE);
        assertEq(oracle3.getExchangeRate(), INITIAL_PRICE);
        
        // Update calculator price
        vm.prank(priceSetter);
        calculator.setSharePrice(UPDATED_PRICE);
        
        // All oracles should reflect the change
        assertEq(oracle.getExchangeRate(), UPDATED_PRICE);
        assertEq(oracle2.getExchangeRate(), UPDATED_PRICE);
        assertEq(oracle3.getExchangeRate(), UPDATED_PRICE);
    }
    
    // ===== MOCK SOURCE TESTS =====
    
    function test_mockIntegration_withMockSource() public {
        ExchangeRateOracle mockOracle = new ExchangeRateOracle(address(mockSource));
        
        assertEq(mockOracle.getExchangeRate(), INITIAL_PRICE);
    }
    
    function test_mockIntegration_varyingRates() public {
        ExchangeRateOracle mockOracle = new ExchangeRateOracle(address(mockSource));
        
        uint256[] memory testRates = new uint256[](6);
        testRates[0] = 0.5e18;
        testRates[1] = 1e18;
        testRates[2] = 1.5e18;
        testRates[3] = 2e18;
        testRates[4] = 10e18;
        testRates[5] = type(uint256).max;
        
        for (uint256 i = 0; i < testRates.length; i++) {
            mockSource.setSharePrice(testRates[i]);
            assertEq(mockOracle.getExchangeRate(), testRates[i]);
        }
    }
    
    // ===== EDGE CASES =====
    
    function test_edgeCases_sourceReturnsZero() public {
        mockSource.setSharePrice(0);
        ExchangeRateOracle mockOracle = new ExchangeRateOracle(address(mockSource));
        
        assertEq(mockOracle.getExchangeRate(), 0);
    }
    
    function test_edgeCases_sourceReturnsMaxUint256() public {
        mockSource.setSharePrice(type(uint256).max);
        ExchangeRateOracle mockOracle = new ExchangeRateOracle(address(mockSource));
        
        assertEq(mockOracle.getExchangeRate(), type(uint256).max);
    }
    
    function test_edgeCases_sourceReturnsOne() public {
        mockSource.setSharePrice(1);
        ExchangeRateOracle mockOracle = new ExchangeRateOracle(address(mockSource));
        
        assertEq(mockOracle.getExchangeRate(), 1);
    }
    
    // ===== INTERFACE COMPLIANCE TESTS =====
    
    function test_interface_IPExchangeRateOracle() public view {
        // Should implement IPExchangeRateOracle
        IPExchangeRateOracle(address(oracle)).getExchangeRate();
    }
    
    // ===== STATE IMMUTABILITY TESTS =====
    
    function test_immutability_exchangeRateSource() public view {
        // EXCHANGE_RATE_SOURCE should be immutable and set correctly
        assertEq(address(oracle.EXCHANGE_RATE_SOURCE()), address(calculator));
    }
    
    function test_immutability_sourceCannotBeChanged() public {
        // There should be no way to change the source after deployment
        address originalSource = address(oracle.EXCHANGE_RATE_SOURCE());
        
        // Attempt various operations that shouldn't affect the source
        oracle.getExchangeRate();
        
        vm.prank(admin);
        oracle.getExchangeRate();
        
        // Source should remain unchanged
        assertEq(address(oracle.EXCHANGE_RATE_SOURCE()), originalSource);
    }
    
    // ===== FUZZ TESTS =====
    
    function testFuzz_getExchangeRate_withVariousSourcePrices(uint256 price) public {
        // Bound to reasonable range
        price = bound(price, 0, type(uint128).max);
        
        mockSource.setSharePrice(price);
        ExchangeRateOracle fuzzOracle = new ExchangeRateOracle(address(mockSource));
        
        assertEq(fuzzOracle.getExchangeRate(), price);
    }
    
    function testFuzz_constructor_withValidSources() public {
        // Test with multiple valid source addresses
        address[] memory sources = new address[](3);
        sources[0] = address(calculator);
        sources[1] = address(mockSource);
        sources[2] = address(new MockExchangeRateSource(1e18));
        
        for (uint256 i = 0; i < sources.length; i++) {
            ExchangeRateOracle fuzzOracle = new ExchangeRateOracle(sources[i]);
            assertEq(address(fuzzOracle.EXCHANGE_RATE_SOURCE()), sources[i]);
        }
    }
}

/**
 * @title MockExchangeRateSource
 * @notice Mock contract implementing IExchangeRateSource for testing
 */
contract MockExchangeRateSource is IExchangeRateSource {
    uint256 private _sharePrice;
    
    constructor(uint256 initialPrice) {
        _sharePrice = initialPrice;
    }
    
    function getSharePrice() external view override returns (uint256) {
        return _sharePrice;
    }
    
    function setSharePrice(uint256 newPrice) external {
        _sharePrice = newPrice;
    }
}