// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../src/MyBank.sol";
import "../src/Vault.sol";
import "../src/MyBankV2.sol";
import "forge-std/Test.sol";
import "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {USDC} from "./mocks/USDC.sol";
import {MockMinimalForwarder} from "./mocks/MockMinimalForwarder.sol";
import "forge-std/console.sol";

contract PermitTest is Test {
    event Deposit(address indexed token, address indexed from, uint256 amount);
    event Withdraw(address indexed token, address indexed to, uint256 amount);
    event NewBank(address indexed newBank);
    uint256 PK;
    address mock_sender;

    address owner = address(0x333);
    MyBank internal bank;
    Vault internal vault;
    USDC internal usdc;
    MyBankV2 internal bankV2;
    ERC1967Proxy internal proxy;
    bytes32 constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
    bytes32 TOKEN_DOMAIN_SEPARATOR;

    function setUp() public {
        bank = new MyBank();
        bankV2 = new MyBankV2();
        proxy = new ERC1967Proxy(address(bank), "");
        bank = MyBank(address(proxy));
        usdc = new USDC();
        PK = 0xBEEF;
        mock_sender = vm.addr(PK);
        TOKEN_DOMAIN_SEPARATOR = usdc.DOMAIN_SEPARATOR();
        address[] memory allowedTokens = new address[](1);
        allowedTokens[0] = address(usdc);
        vm.startPrank(owner);
        vault = new Vault();
        bank.initialize(address(vault), address(0), allowedTokens);
        vm.stopPrank();
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

    function testFuzz_DepositWithPermit(uint256 amount) public {
        vm.assume(amount > 0);
        helper_setupBank();
        usdc.mint(mock_sender, amount);
        assertEq(usdc.balanceOf(mock_sender), amount);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            PK,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    TOKEN_DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            mock_sender,
                            address(bank),
                            amount,
                            usdc.nonces(mock_sender),
                            block.timestamp
                        )
                    )
                )
            )
        );
        vm.startPrank(mock_sender);

        vm.expectEmit(true, true, false, false);
        emit Deposit(address(usdc), mock_sender, amount);
        bank.depositWithPermit(address(usdc), amount, block.timestamp, v, r, s);
        vm.stopPrank();
        // assert vault balance change
        assertEq(usdc.balanceOf(address(vault)), amount);
    }

    // test deposit fails with non permit token
    //function test_DepositWithPermitFail(
}
