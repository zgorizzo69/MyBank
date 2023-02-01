// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../src/MyBank.sol";
import "../src/Vault.sol";
import "../src/MyBankV2.sol";
import "forge-std/Test.sol";
import "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockMinimalForwarder} from "./mocks/MockMinimalForwarder.sol";
import "forge-std/console.sol";

contract BankTest is Test {
    event Deposit(address indexed token, address indexed from, uint256 amount);
    event Withdraw(address indexed token, address indexed to, uint256 amount);
    event NewBank(address indexed newBank);
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    address mock_sender = address(0x111);
    address mock_recipient = address(0x222);
    address owner = address(0x333);
    MyBank internal bank;
    Vault internal vault;
    MockERC20 internal mockERC20;
    MyBankV2 internal bankV2;
    ERC1967Proxy internal proxy;

    function setUp() public {
        bank = new MyBank();
        bankV2 = new MyBankV2();
        proxy = new ERC1967Proxy(address(bank), "");
        bank = MyBank(address(proxy));
        mockERC20 = new MockERC20("Mock", "MCK", 18);

        address[] memory allowedTokens = new address[](1);
        allowedTokens[0] = address(mockERC20);
        vm.startPrank(owner);
        vault = new Vault();
        bank.initialize(address(vault), address(0), allowedTokens);
        vm.stopPrank();
    }

    function helper_makeDeposit(uint256 amount) public {
        vm.startPrank(mock_sender);
        mockERC20.mint(mock_sender, amount);
        mockERC20.approve(address(bank), amount);
        vm.expectEmit(true, true, true, true);
        emit Deposit(address(mockERC20), mock_sender, amount);
        bank.deposit(address(mockERC20), amount);
        vm.stopPrank();
        // assert vault balance change
        assertEq(mockERC20.balanceOf(address(vault)), amount);
        // assert mock sender bank balance change
        assertEq(bank.balanceOf(address(mockERC20), mock_sender), amount);
    }

    function helper_setupBank() public {
        // unpause bank
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, false);
        emit NewBank(address(bank));
        vault.setBank(address(bank));

        bank.unpause();
        // unpause vault
        vault.unpause();
        // set bank

        vm.stopPrank();
    }

    function test_Bank_IsPaused() public {
        assertEq(bank.paused(), true);
        vm.startPrank(owner);
        bank.unpause();
        assertEq(bank.paused(), false);
        vm.stopPrank();
    }

    function test_Vault_IsPaused() public {
        assertEq(vault.paused(), true);
        vm.startPrank(owner);
        vault.unpause();
        assertEq(vault.paused(), false);
        vm.stopPrank();
    }

    function test_Deposit_RevertIf_BankIsPaused() public {
        mockERC20.mint(mock_sender, 10e18);
        assertEq(mockERC20.balanceOf(mock_sender), 10e18);

        vm.startPrank(mock_sender);
        mockERC20.approve(address(bank), 10e18);
        vm.expectRevert("Pausable: paused");
        bank.deposit(address(mockERC20), 10e18);
        vm.stopPrank();

        // no balance inside bank as the deposit was reverted
        assertEq(bank.balanceOf(address(mockERC20), mock_sender), 0);
        // no balance inside vault as the deposit was reverted
        assertEq(mockERC20.balanceOf(address(vault)), 0);
        // mock_sender balance is not changed
        assertEq(mockERC20.balanceOf(mock_sender), 10e18);
    }

    function test_AddAllowedToken_RevertIf_NotAdmin() public {
        helper_setupBank();
        vm.startPrank(mock_sender);
        vm.expectRevert("Ownable: caller is not the owner");
        bank.addAllowedToken(address(mockERC20));

        vm.stopPrank();
    }

    function test_AddAllowedToken_RevertIf_token0() public {
        helper_setupBank();
        vm.startPrank(owner);
        vm.expectRevert("newToken=0");
        bank.addAllowedToken(address(0));

        vm.stopPrank();
    }

    function test_AddAllowedToken() public {
        helper_setupBank();

        vm.expectEmit(true, false, false, false);
        emit TokenAdded(address(0x123));
        vm.startPrank(owner);
        bank.addAllowedToken(address(0x123));

        vm.stopPrank();
    }

    function test_RemoveAllowedToken_RevertIf_NotAdmin() public {
        helper_setupBank();
        vm.startPrank(mock_sender);
        vm.expectRevert("Ownable: caller is not the owner");
        bank.removeAllowedToken(address(mockERC20));

        vm.stopPrank();
    }

    function test_RemoveAllowedToken_RevertIf_tokenIsNotAllowed() public {
        helper_setupBank();
        vm.startPrank(owner);
        vm.expectRevert("tokenNotAllowed");
        bank.removeAllowedToken(address(0x123));

        vm.stopPrank();
    }

    function test_RemoveAllowedToken() public {
        helper_setupBank();

        vm.expectEmit(true, false, false, false);
        emit TokenRemoved(address(mockERC20));
        vm.startPrank(owner);
        bank.removeAllowedToken(address(mockERC20));

        vm.stopPrank();
    }

    function testFuzz_Deposit(uint256 amount) public {
        vm.assume(amount > 0);
        helper_setupBank();
        mockERC20.mint(mock_sender, amount);
        assertEq(mockERC20.balanceOf(mock_sender), amount);

        vm.startPrank(mock_sender);
        mockERC20.approve(address(bank), amount);
        vm.expectEmit(true, true, false, true);
        emit Deposit(address(mockERC20), mock_sender, amount);
        bank.deposit(address(mockERC20), amount);
        vm.stopPrank();
        // assert vault balance change
        assertEq(mockERC20.balanceOf(address(vault)), amount);
    }

    function test_Withdraw_RevertIf_VaultIsPaused() public {
        // unpause bank
        vm.prank(owner);
        bank.unpause();

        uint256 amount = 10e18;
        helper_makeDeposit(amount);

        vm.startPrank(mock_sender);
        vm.expectRevert("Pausable: paused");
        bank.withdraw(address(mockERC20), mock_sender, amount);

        vm.stopPrank();
        /// assert bank balance did not change
        assertEq(bank.balanceOf(address(mockERC20), mock_sender), amount);
        // assert vault balance did not change
        assertEq(mockERC20.balanceOf(address(vault)), amount);
    }

    function test_Withdraw_RevertIf_BankIsNotSet() public {
        // unpause bank
        vm.startPrank(owner);
        bank.unpause();
        // unpause vault
        vault.unpause();
        vm.stopPrank();

        uint256 amount = 10e18;
        helper_makeDeposit(amount);
        vm.startPrank(mock_sender);
        vm.expectRevert(
            "AccessControl: account 0xf62849f9a0b5bf2913b396098f7c7019b51a820a is missing role 0x591fa5458fe051cc8c02c405479bd38e00713c98dbd3db209d982048f1e638fa"
        );
        bank.withdraw(address(mockERC20), mock_sender, amount);

        vm.stopPrank();
        /// assert bank balance did not change
        assertEq(bank.balanceOf(address(mockERC20), mock_sender), amount);
        // assert vault balance did not change
        assertEq(mockERC20.balanceOf(address(vault)), amount);
    }

    function testFuzz_Withdraw(uint256 amount) public {
        vm.assume(amount > 1);
        helper_setupBank();
        helper_makeDeposit(amount);
        vm.expectEmit(true, true, true, true);
        uint256 withdrawnAmount = amount / 2;
        emit Withdraw(address(mockERC20), mock_recipient, withdrawnAmount);
        vm.prank(mock_sender);
        bank.withdraw(address(mockERC20), mock_recipient, withdrawnAmount);
        // assert bank balance is still 0 for mock recipeint has the token as been withdrawn and not internally transfered
        assertEq(bank.balanceOf(address(mockERC20), mock_recipient), 0);
        // assert bank balance changed for mock_sender
        assertEq(
            bank.balanceOf(address(mockERC20), mock_sender),
            amount - withdrawnAmount
        );
        // assert vault balance changed as the token has been withdrawn
        assertEq(mockERC20.balanceOf(address(vault)), amount - withdrawnAmount);
        // assert token balance changed for mock_recipient as the token has been withdrawn
        assertEq(mockERC20.balanceOf(mock_recipient), withdrawnAmount);
    }

    function testUpgrade() public {
        vm.prank(address(owner));
        bank.upgradeTo(address(bankV2));
        bankV2 = MyBankV2(address(proxy));
        assertEq(bankV2.version(), 1);

        bankV2.increaseVersion();
        assertEq(bankV2.version(), 2);
    }

    function testUpgradeFail() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vm.prank(address(0));
        bank.upgradeTo(address(bankV2));
    }

    function test_Meta() public {
        MockMinimalForwarder newForwarder = new MockMinimalForwarder();
        vm.prank(owner);
        bank.setTrustedForwarder(address(newForwarder));
    }
}
