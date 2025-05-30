// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {SharePriceCalculator} from "../src/SharePriceCalculator.sol";
import {ExchangeRateOracle} from "../src/ExchangeRateOracle.sol";
import {IPExchangeRateOracle} from "pendle-sy/interfaces/IPExchangeRateOracle.sol";
import {ISharePriceCalculator} from "../src/interfaces/ISharePriceCalculator.sol";
import {IExchangeRateSource} from "../src/interfaces/IExchangeRateSource.sol";

/**
 * @title SharePriceCalculatorIntegrationTest
 * @notice Integration tests for SharePriceCalculator and ExchangeRateOracle
 * @dev Tests end-to-end workflows, role management scenarios, and complex interactions
 */
contract SharePriceCalculatorIntegrationTest is Test {
    SharePriceCalculator calculator;
    ExchangeRateOracle oracle;
    
    address admin;
    address priceSetter1;
    address priceSetter2;
    address alice;
    address bob;
    address charlie;
    
    uint256 constant INITIAL_PRICE = 1e18;
    
    // Events
    event SharePriceSet(uint256 oldPrice, uint256 newPrice);
    
    function setUp() public {
        admin = address(0x2001);
        priceSetter1 = address(0x2002);
        priceSetter2 = address(0x2003);
        alice = address(0x2004);
        bob = address(0x2005);
        charlie = address(0x2006);
        
        // Deploy calculator
        calculator = new SharePriceCalculator(INITIAL_PRICE, admin, priceSetter1);
        
        // Deploy oracle using calculator as source
        oracle = new ExchangeRateOracle(address(calculator));
    }
    
    // ===== END-TO-END WORKFLOW TESTS =====
    
    function test_e2e_basicPriceUpdateWorkflow() public {
        // 1. Initial state verification
        assertEq(calculator.getSharePrice(), INITIAL_PRICE);
        assertEq(oracle.getExchangeRate(), INITIAL_PRICE);
        
        // 2. Price setter updates price
        uint256 newPrice = 1.5e18;
        vm.prank(priceSetter1);
        calculator.setSharePrice(newPrice);
        
        // 3. Verify both contracts reflect the change
        assertEq(calculator.getSharePrice(), newPrice);
        assertEq(oracle.getExchangeRate(), newPrice);
        
        // 4. Multiple sequential updates
        uint256[] memory prices = new uint256[](3);
        prices[0] = 2e18;
        prices[1] = 2.5e18;
        prices[2] = 3e18;
        
        for (uint256 i = 0; i < prices.length; i++) {
            vm.prank(priceSetter1);
            calculator.setSharePrice(prices[i]);
            
            assertEq(calculator.getSharePrice(), prices[i]);
            assertEq(oracle.getExchangeRate(), prices[i]);
        }
    }
    
    function test_e2e_multipleOraclesWorkflow() public {
        // Deploy multiple oracles using same calculator
        ExchangeRateOracle oracle2 = new ExchangeRateOracle(address(calculator));
        ExchangeRateOracle oracle3 = new ExchangeRateOracle(address(calculator));
        
        // All oracles should return initial price
        assertEq(oracle.getExchangeRate(), INITIAL_PRICE);
        assertEq(oracle2.getExchangeRate(), INITIAL_PRICE);
        assertEq(oracle3.getExchangeRate(), INITIAL_PRICE);
        
        // Update calculator price
        uint256 newPrice = 2.5e18;
        vm.prank(priceSetter1);
        calculator.setSharePrice(newPrice);
        
        // All oracles should reflect the change
        assertEq(oracle.getExchangeRate(), newPrice);
        assertEq(oracle2.getExchangeRate(), newPrice);
        assertEq(oracle3.getExchangeRate(), newPrice);
        
        // Test with another update
        uint256 finalPrice = 4e18;
        vm.prank(priceSetter1);
        calculator.setSharePrice(finalPrice);
        
        assertEq(oracle.getExchangeRate(), finalPrice);
        assertEq(oracle2.getExchangeRate(), finalPrice);
        assertEq(oracle3.getExchangeRate(), finalPrice);
    }
    
    function test_e2e_complexRoleManagementWorkflow() public {
        // 1. Grant price setter role to alice
        vm.startPrank(admin);
        calculator.grantRole(calculator.PRICE_SETTER_ROLE(), alice);
        vm.stopPrank();
        
        // 2. Both price setters should work
        vm.startPrank(priceSetter1);
        calculator.setSharePrice(1.5e18);
        vm.stopPrank();
        assertEq(oracle.getExchangeRate(), 1.5e18);
        
        vm.startPrank(alice);
        calculator.setSharePrice(2e18);
        vm.stopPrank();
        assertEq(oracle.getExchangeRate(), 2e18);
        
        // 3. Grant admin role to bob
        vm.startPrank(admin);
        calculator.grantRole(calculator.DEFAULT_ADMIN_ROLE(), bob);
        vm.stopPrank();
        
        // 4. Bob should be able to grant roles
        vm.startPrank(bob);
        calculator.grantRole(calculator.PRICE_SETTER_ROLE(), charlie);
        vm.stopPrank();
        
        // 5. Charlie should now be able to set prices
        vm.startPrank(charlie);
        calculator.setSharePrice(3e18);
        vm.stopPrank();
        assertEq(oracle.getExchangeRate(), 3e18);
        
        // 6. Revoke alice's role
        vm.startPrank(admin);
        calculator.revokeRole(calculator.PRICE_SETTER_ROLE(), alice);
        vm.stopPrank();
        
        // 7. Alice should no longer be able to set prices
        vm.startPrank(alice);
        bool reverted = false;
        try calculator.setSharePrice(4e18) {
            // Should not reach here
        } catch {
            reverted = true;
        }
        vm.stopPrank();
        assertTrue(reverted, "setSharePrice should have reverted");
        
        // 8. But charlie and priceSetter1 should still work
        vm.startPrank(charlie);
        calculator.setSharePrice(4e18);
        vm.stopPrank();
        assertEq(oracle.getExchangeRate(), 4e18);
    }
    
    // ===== CROSS-CONTRACT INTERACTION TESTS =====
    
    function test_crossContract_oracleIndependentOfCalculatorRoles() public {
        // Oracle should work regardless of calculator's role changes
        
        // Initial state
        assertEq(oracle.getExchangeRate(), INITIAL_PRICE);
        
        // Remove all price setter roles
        vm.startPrank(admin);
        calculator.revokeRole(calculator.PRICE_SETTER_ROLE(), priceSetter1);
        vm.stopPrank();
        
        // Oracle should still return current price
        assertEq(oracle.getExchangeRate(), INITIAL_PRICE);
        
        // Grant role to alice and update price
        vm.startPrank(admin);
        calculator.grantRole(calculator.PRICE_SETTER_ROLE(), alice);
        vm.stopPrank();
        
        vm.startPrank(alice);
        calculator.setSharePrice(2e18);
        vm.stopPrank();
        
        // Oracle should reflect the change
        assertEq(oracle.getExchangeRate(), 2e18);
    }
    
    function test_crossContract_multipleCalculatorsAndOracles() public {
        // Deploy second calculator with different initial price
        SharePriceCalculator calculator2 = new SharePriceCalculator(
            2e18, 
            admin, 
            priceSetter2
        );
        
        // Deploy oracles for both calculators
        ExchangeRateOracle oracle1 = new ExchangeRateOracle(address(calculator));
        ExchangeRateOracle oracle2 = new ExchangeRateOracle(address(calculator2));
        
        // Verify initial states
        assertEq(oracle1.getExchangeRate(), INITIAL_PRICE);
        assertEq(oracle2.getExchangeRate(), 2e18);
        
        // Update both calculators
        vm.prank(priceSetter1);
        calculator.setSharePrice(1.5e18);
        
        vm.prank(priceSetter2);
        calculator2.setSharePrice(3e18);
        
        // Each oracle should reflect its calculator's price
        assertEq(oracle1.getExchangeRate(), 1.5e18);
        assertEq(oracle2.getExchangeRate(), 3e18);
    }
    
    // ===== EVENT INTEGRATION TESTS =====
    
    function test_events_priceUpdatePropagation() public {
        uint256 newPrice = 2e18;
        
        // Should emit event from calculator
        vm.expectEmit(true, true, true, true);
        emit SharePriceSet(INITIAL_PRICE, newPrice);
        
        vm.prank(priceSetter1);
        calculator.setSharePrice(newPrice);
        
        // Oracle should immediately reflect the change
        assertEq(oracle.getExchangeRate(), newPrice);
    }
    
    // ===== STRESS TESTS =====
    
    function test_stress_rapidPriceUpdates() public {
        uint256 currentPrice = INITIAL_PRICE;
        
        // Perform 50 rapid price updates
        for (uint256 i = 1; i <= 50; i++) {
            currentPrice = currentPrice + 1e16; // Increase by 0.01 each time
            
            vm.prank(priceSetter1);
            calculator.setSharePrice(currentPrice);
            
            // Oracle should always be in sync
            assertEq(oracle.getExchangeRate(), currentPrice);
        }
    }
    
    function test_stress_multipleOraclesConcurrentAccess() public {
        // Deploy 10 oracles
        ExchangeRateOracle[] memory oracles = new ExchangeRateOracle[](10);
        for (uint256 i = 0; i < 10; i++) {
            oracles[i] = new ExchangeRateOracle(address(calculator));
        }
        
        // Update price multiple times
        uint256[] memory prices = new uint256[](5);
        prices[0] = 1.2e18;
        prices[1] = 1.8e18;
        prices[2] = 2.3e18;
        prices[3] = 3.1e18;
        prices[4] = 4.7e18;
        
        for (uint256 i = 0; i < prices.length; i++) {
            vm.prank(priceSetter1);
            calculator.setSharePrice(prices[i]);
            
            // All oracles should reflect the change
            for (uint256 j = 0; j < oracles.length; j++) {
                assertEq(oracles[j].getExchangeRate(), prices[i]);
            }
        }
    }
    
    // ===== INTERFACE INTEGRATION TESTS =====
    
    function test_interfaces_crossContractCompatibility() public {
        // Test that contracts work through their interfaces
        ISharePriceCalculator iCalculator = ISharePriceCalculator(address(calculator));
        IPExchangeRateOracle iOracle = IPExchangeRateOracle(address(oracle));
        IExchangeRateSource iSource = IExchangeRateSource(address(calculator));
        
        // Initial state through interfaces
        assertEq(iCalculator.getSharePrice(), INITIAL_PRICE);
        assertEq(iOracle.getExchangeRate(), INITIAL_PRICE);
        assertEq(iSource.getSharePrice(), INITIAL_PRICE);
        
        // Update through interface (note: access control still applies)
        vm.prank(priceSetter1);
        iCalculator.setSharePrice(2e18);
        
        // Verify through all interfaces
        assertEq(iCalculator.getSharePrice(), 2e18);
        assertEq(iOracle.getExchangeRate(), 2e18);
        assertEq(iSource.getSharePrice(), 2e18);
    }
    
    // ===== EDGE CASE INTEGRATION TESTS =====
    
    function test_edgeCase_calculatorDeployedAfterOracle() public {
        // Deploy calculator first
        SharePriceCalculator newCalculator = new SharePriceCalculator(
            5e18, 
            admin, 
            priceSetter1
        );
        
        // Deploy oracle after calculator is ready
        ExchangeRateOracle newOracle = new ExchangeRateOracle(address(newCalculator));
        
        // Should work correctly
        assertEq(newOracle.getExchangeRate(), 5e18);
        
        // Update should propagate
        vm.prank(priceSetter1);
        newCalculator.setSharePrice(7e18);
        
        assertEq(newOracle.getExchangeRate(), 7e18);
    }
    
    function test_edgeCase_extremePriceValues() public {
        // Test with slightly increased price (since we can only increase)
        vm.prank(priceSetter1);
        calculator.setSharePrice(INITIAL_PRICE + 1);
        assertEq(oracle.getExchangeRate(), INITIAL_PRICE + 1);
        
        // Test with very large price
        vm.prank(priceSetter1);
        calculator.setSharePrice(type(uint128).max);
        assertEq(oracle.getExchangeRate(), type(uint128).max);
    }
    
    // ===== FUZZ INTEGRATION TESTS =====
    
    function testFuzz_integration_priceUpdatePropagation(uint256 price) public {
        // Bound to reasonable range to avoid reverts
        price = bound(price, INITIAL_PRICE, type(uint128).max);
        
        vm.prank(priceSetter1);
        calculator.setSharePrice(price);
        
        assertEq(oracle.getExchangeRate(), price);
    }
    
    function testFuzz_integration_multipleUpdates(
        uint256 price1,
        uint256 price2,
        uint256 price3
    ) public {
        // Ensure monotonic increasing prices
        price1 = bound(price1, INITIAL_PRICE, type(uint64).max);
        price2 = bound(price2, price1, type(uint64).max);
        price3 = bound(price3, price2, type(uint64).max);
        
        vm.startPrank(priceSetter1);
        
        calculator.setSharePrice(price1);
        assertEq(oracle.getExchangeRate(), price1);
        
        calculator.setSharePrice(price2);
        assertEq(oracle.getExchangeRate(), price2);
        
        calculator.setSharePrice(price3);
        assertEq(oracle.getExchangeRate(), price3);
        
        vm.stopPrank();
    }
}