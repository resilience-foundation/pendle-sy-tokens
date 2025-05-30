// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {SharePriceCalculator} from "../src/SharePriceCalculator.sol";
import {ISharePriceCalculator} from "../src/interfaces/ISharePriceCalculator.sol";
import {IExchangeRateSource} from "../src/interfaces/IExchangeRateSource.sol";

/**
 * @title SharePriceCalculatorTest
 * @notice Comprehensive test suite for SharePriceCalculator contract
 * @dev Tests constructor, access control, price management, and edge cases
 */
contract SharePriceCalculatorTest is Test {
    SharePriceCalculator calculator;
    
    address admin;
    address priceSetter;
    address alice;
    address bob;
    
    uint256 constant INITIAL_PRICE = 1e18;
    uint256 constant HIGHER_PRICE = 2e18;
    uint256 constant LOWER_PRICE = 5e17;
    
    // Events
    event SharePriceSet(uint256 oldPrice, uint256 newPrice);
    
    function setUp() public {
        admin = address(0x1001);
        priceSetter = address(0x1002);
        alice = address(0x1003);
        bob = address(0x1004);
        
        calculator = new SharePriceCalculator(INITIAL_PRICE, admin, priceSetter);
    }
    
    // ===== CONSTRUCTOR TESTS =====
    
    function test_constructor_success_withValidParams() public {
        SharePriceCalculator newCalculator = new SharePriceCalculator(
            INITIAL_PRICE, 
            admin, 
            priceSetter
        );
        
        assertEq(newCalculator.getSharePrice(), INITIAL_PRICE);
        assertTrue(newCalculator.hasRole(newCalculator.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(newCalculator.hasRole(newCalculator.PRICE_SETTER_ROLE(), priceSetter));
    }
    
    function test_constructor_initialSharePrice_setCorrectly() public view {
        assertEq(calculator.getSharePrice(), INITIAL_PRICE);
    }
    
    function test_constructor_roles_grantedCorrectly() public view {
        assertTrue(calculator.hasRole(calculator.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(calculator.hasRole(calculator.PRICE_SETTER_ROLE(), priceSetter));
        assertFalse(calculator.hasRole(calculator.PRICE_SETTER_ROLE(), admin));
        assertFalse(calculator.hasRole(calculator.DEFAULT_ADMIN_ROLE(), priceSetter));
    }
    
    function test_constructor_revert_zeroInitialPrice() public {
        vm.expectRevert(SharePriceCalculator.InvalidPrice.selector);
        new SharePriceCalculator(0, admin, priceSetter);
    }
    
    function test_constructor_revert_zeroAdminAddress() public {
        vm.expectRevert(SharePriceCalculator.ZeroAddress.selector);
        new SharePriceCalculator(INITIAL_PRICE, address(0), priceSetter);
    }
    
    function test_constructor_revert_zeroPriceSetterAddress() public {
        vm.expectRevert(SharePriceCalculator.ZeroAddress.selector);
        new SharePriceCalculator(INITIAL_PRICE, admin, address(0));
    }
    
    // ===== setSharePrice ACCESS CONTROL TESTS =====
    
    function test_setSharePrice_success_authorizedUser() public {
        vm.prank(priceSetter);
        calculator.setSharePrice(HIGHER_PRICE);
        
        assertEq(calculator.getSharePrice(), HIGHER_PRICE);
    }
    
    function test_setSharePrice_revert_unauthorizedUser() public {
        vm.expectRevert();
        vm.prank(alice);
        calculator.setSharePrice(HIGHER_PRICE);
    }
    
    function test_setSharePrice_revert_unauthorizedAdmin() public {
        vm.expectRevert();
        vm.startPrank(admin);
        calculator.setSharePrice(HIGHER_PRICE);
        vm.stopPrank();
    }
    
    function test_setSharePrice_success_multipleAuthorizedUsers() public {
        // Grant price setter role to alice
        vm.startPrank(admin);
        calculator.grantRole(calculator.PRICE_SETTER_ROLE(), alice);
        vm.stopPrank();
        
        // Both priceSetter and alice should be able to set price
        vm.startPrank(priceSetter);
        calculator.setSharePrice(1.5e18);
        vm.stopPrank();
        assertEq(calculator.getSharePrice(), 1.5e18);
        
        vm.startPrank(alice);
        calculator.setSharePrice(HIGHER_PRICE);
        vm.stopPrank();
        assertEq(calculator.getSharePrice(), HIGHER_PRICE);
    }
    
    // ===== setSharePrice PRICE VALIDATION TESTS =====
    
    function test_setSharePrice_success_increasePrice() public {
        vm.prank(priceSetter);
        calculator.setSharePrice(HIGHER_PRICE);
        
        assertEq(calculator.getSharePrice(), HIGHER_PRICE);
    }
    
    function test_setSharePrice_success_samePrice() public {
        vm.prank(priceSetter);
        calculator.setSharePrice(INITIAL_PRICE);
        
        assertEq(calculator.getSharePrice(), INITIAL_PRICE);
    }
    
    function test_setSharePrice_revert_decreasePrice() public {
        // First increase the price
        vm.startPrank(priceSetter);
        calculator.setSharePrice(HIGHER_PRICE);
        
        // Then try to decrease it
        vm.expectRevert(SharePriceCalculator.InvalidPrice.selector);
        calculator.setSharePrice(LOWER_PRICE);
        vm.stopPrank();
    }
    
    function test_setSharePrice_success_largeIncrease() public {
        uint256 largePrice = 100e18;
        
        vm.prank(priceSetter);
        calculator.setSharePrice(largePrice);
        
        assertEq(calculator.getSharePrice(), largePrice);
    }
    
    // ===== setSharePrice EVENT EMISSION TESTS =====
    
    function test_setSharePrice_emitsCorrectEvent() public {
        vm.expectEmit(true, true, true, true);
        emit SharePriceSet(INITIAL_PRICE, HIGHER_PRICE);
        
        vm.prank(priceSetter);
        calculator.setSharePrice(HIGHER_PRICE);
    }
    
    function test_setSharePrice_emitsCorrectEvent_samePrice() public {
        vm.expectEmit(true, true, true, true);
        emit SharePriceSet(INITIAL_PRICE, INITIAL_PRICE);
        
        vm.prank(priceSetter);
        calculator.setSharePrice(INITIAL_PRICE);
    }
    
    // ===== setSharePrice STATE UPDATE TESTS =====
    
    function test_setSharePrice_updatesStoredPrice() public {
        uint256 newPrice = 1.5e18;
        
        vm.prank(priceSetter);
        calculator.setSharePrice(newPrice);
        
        assertEq(calculator.getSharePrice(), newPrice);
        
        // Update again
        uint256 newerPrice = 3e18;
        vm.prank(priceSetter);
        calculator.setSharePrice(newerPrice);
        
        assertEq(calculator.getSharePrice(), newerPrice);
    }
    
    // ===== getSharePrice TESTS =====
    
    function test_getSharePrice_returnsInitialPrice() public view {
        assertEq(calculator.getSharePrice(), INITIAL_PRICE);
    }
    
    function test_getSharePrice_returnsUpdatedPrice() public {
        vm.prank(priceSetter);
        calculator.setSharePrice(HIGHER_PRICE);
        
        assertEq(calculator.getSharePrice(), HIGHER_PRICE);
    }
    
    function test_getSharePrice_publicAccess() public {
        // Should be callable by anyone without reverting
        calculator.getSharePrice();
        
        // Test from different addresses
        vm.prank(alice);
        calculator.getSharePrice();
        
        vm.prank(bob);
        calculator.getSharePrice();
    }
    
    // ===== ROLE MANAGEMENT TESTS =====
    
    function test_debug_roleCheck() public view {
        console.log("Admin address:", admin);
        console.log("Has admin role:", calculator.hasRole(calculator.DEFAULT_ADMIN_ROLE(), admin));
        console.log("Default admin role:", vm.toString(calculator.DEFAULT_ADMIN_ROLE()));
    }
    
    function test_roleManagement_adminCanGrantPriceSetterRole() public {
        console.log("Test: Admin address:", admin);
        console.log("Test: Alice address:", alice);
        console.log("Test: Current sender:", msg.sender);
        console.log("Test: Admin has role:", calculator.hasRole(calculator.DEFAULT_ADMIN_ROLE(), admin));
        
        vm.startPrank(admin);
        calculator.grantRole(calculator.PRICE_SETTER_ROLE(), alice);
        vm.stopPrank();
        
        assertTrue(calculator.hasRole(calculator.PRICE_SETTER_ROLE(), alice));
        
        // Alice should now be able to set price
        vm.startPrank(alice);
        calculator.setSharePrice(HIGHER_PRICE);
        vm.stopPrank();
        assertEq(calculator.getSharePrice(), HIGHER_PRICE);
    }
    
    function test_roleManagement_adminCanRevokePriceSetterRole() public {
        // First grant role to alice
        vm.startPrank(admin);
        calculator.grantRole(calculator.PRICE_SETTER_ROLE(), alice);
        
        // Then revoke it
        calculator.revokeRole(calculator.PRICE_SETTER_ROLE(), alice);
        vm.stopPrank();
        
        assertFalse(calculator.hasRole(calculator.PRICE_SETTER_ROLE(), alice));
        
        // Alice should no longer be able to set price
        vm.expectRevert();
        vm.startPrank(alice);
        calculator.setSharePrice(HIGHER_PRICE);
        vm.stopPrank();
    }
    
    function test_roleManagement_adminCanTransferAdminRole() public {
        vm.startPrank(admin);
        calculator.grantRole(calculator.DEFAULT_ADMIN_ROLE(), alice);
        vm.stopPrank();
        
        assertTrue(calculator.hasRole(calculator.DEFAULT_ADMIN_ROLE(), alice));
        
        // Alice should now be able to grant roles
        vm.startPrank(alice);
        calculator.grantRole(calculator.PRICE_SETTER_ROLE(), bob);
        vm.stopPrank();
        
        assertTrue(calculator.hasRole(calculator.PRICE_SETTER_ROLE(), bob));
    }
    
    function test_roleManagement_nonAdminCannotGrantRoles() public {
        vm.startPrank(alice);
        
        bool reverted = false;
        try calculator.grantRole(calculator.PRICE_SETTER_ROLE(), bob) {
            // Should not reach here
        } catch {
            reverted = true;
        }
        
        vm.stopPrank();
        
        assertTrue(reverted, "grantRole should have reverted");
        assertFalse(calculator.hasRole(calculator.PRICE_SETTER_ROLE(), bob), "Bob should not have price setter role");
    }
    
    function test_roleManagement_revokedUserCannotSetPrice() public {
        // Revoke original price setter's role
        vm.startPrank(admin);
        calculator.revokeRole(calculator.PRICE_SETTER_ROLE(), priceSetter);
        vm.stopPrank();
        
        // Should not be able to set price anymore
        vm.expectRevert();
        vm.startPrank(priceSetter);
        calculator.setSharePrice(HIGHER_PRICE);
        vm.stopPrank();
    }
    
    // ===== EDGE CASES AND BOUNDARY TESTS =====
    
    function test_edgeCases_maxUint256Price() public {
        uint256 maxPrice = type(uint256).max;
        
        vm.prank(priceSetter);
        calculator.setSharePrice(maxPrice);
        
        assertEq(calculator.getSharePrice(), maxPrice);
    }
    
    function test_edgeCases_priceSetterRoleRevocation() public {
        // Set a price first
        vm.prank(priceSetter);
        calculator.setSharePrice(HIGHER_PRICE);
        
        // Revoke price setter role
        vm.startPrank(admin);
        calculator.revokeRole(calculator.PRICE_SETTER_ROLE(), priceSetter);
        vm.stopPrank();
        
        // Price should remain the same
        assertEq(calculator.getSharePrice(), HIGHER_PRICE);
        
        // But cannot set new price
        vm.expectRevert();
        vm.startPrank(priceSetter);
        calculator.setSharePrice(3e18);
        vm.stopPrank();
    }
    
    function test_edgeCases_multipleAdmins() public {
        // Grant admin role to alice
        vm.startPrank(admin);
        calculator.grantRole(calculator.DEFAULT_ADMIN_ROLE(), alice);
        vm.stopPrank();
        
        // Both should be able to manage roles
        vm.startPrank(admin);
        calculator.grantRole(calculator.PRICE_SETTER_ROLE(), bob);
        vm.stopPrank();
        
        vm.startPrank(alice);
        calculator.revokeRole(calculator.PRICE_SETTER_ROLE(), bob);
        vm.stopPrank();
        
        assertFalse(calculator.hasRole(calculator.PRICE_SETTER_ROLE(), bob));
    }
    
    // ===== INTERFACE COMPLIANCE TESTS =====
    
    function test_interface_ISharePriceCalculator() public view {
        // Should implement ISharePriceCalculator
        ISharePriceCalculator(address(calculator)).getSharePrice();
    }
    
    function test_interface_IExchangeRateSource() public view {
        // Should implement IExchangeRateSource  
        IExchangeRateSource(address(calculator)).getSharePrice();
    }
    
    // ===== FUZZ TESTS =====
    
    function testFuzz_setSharePrice_validIncreasesOnly(
        uint256 price1, 
        uint256 price2
    ) public {
        // Bound prices to reasonable range
        price1 = bound(price1, 1e18, type(uint128).max);
        price2 = bound(price2, 1e18, type(uint128).max);
        
        // Deploy calculator with price1
        SharePriceCalculator fuzzCalculator = new SharePriceCalculator(
            price1, 
            admin, 
            priceSetter
        );
        
        vm.startPrank(priceSetter);
        
        if (price2 >= price1) {
            // Should succeed if price2 >= price1
            fuzzCalculator.setSharePrice(price2);
            assertEq(fuzzCalculator.getSharePrice(), price2);
        } else {
            // Should revert if price2 < price1
            vm.expectRevert(SharePriceCalculator.InvalidPrice.selector);
            fuzzCalculator.setSharePrice(price2);
        }
        
        vm.stopPrank();
    }
    
    function testFuzz_constructor_validInitialPrices(uint256 initialPrice) public {
        // Bound to avoid zero and overflow
        initialPrice = bound(initialPrice, 1, type(uint128).max);
        
        SharePriceCalculator fuzzCalculator = new SharePriceCalculator(
            initialPrice, 
            admin, 
            priceSetter
        );
        
        assertEq(fuzzCalculator.getSharePrice(), initialPrice);
    }
}