// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import {MyBank} from "../src/MyBank.sol";

import "../src/Vault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MyBankHarness is MyBank {
    // Deploy this contract then call this method to test `myInternalMethod`.
    function exposed_domainSeparatorV4() external returns (bytes32) {
        return _domainSeparatorV4();
    }
}

// forge test --match-contract EIP712
contract EIP712Test is Test {
    bytes32 private constant TYPE_HASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    bytes32 private constant HASHED_NAME = keccak256("MyBank");
    bytes32 private constant HASHED_VERSION = keccak256("0.0.1");
    MockERC20 internal mockERC20;
    MyBankHarness bank;
    Vault internal vault;
    ERC1967Proxy internal proxy;
    address owner = address(0x111);

    function setUp() public {
        bank = new MyBankHarness();

        proxy = new ERC1967Proxy(address(bank), "");
        bank = MyBankHarness(address(proxy));
        mockERC20 = new MockERC20("Mock", "MCK", 18);

        address[] memory allowedTokens = new address[](1);
        allowedTokens[0] = address(mockERC20);
        vm.startPrank(owner);
        vault = new Vault();
        bank.initialize(address(vault), address(0), allowedTokens);
        vm.stopPrank();
    }

    function testDomainSeparator() public {
        bytes32 expectedDomainSeparator = keccak256(
            abi.encode(
                TYPE_HASH,
                HASHED_NAME,
                HASHED_VERSION,
                block.chainid,
                address(bank)
            )
        );

        assertEq(bank.exposed_domainSeparatorV4(), expectedDomainSeparator);
    }

    function testDomainSeparatorAfterFork() public {
        bytes32 beginningSeparator = bank.exposed_domainSeparatorV4();
        uint256 newChainId = block.chainid + 1;
        vm.chainId(newChainId);
        assertTrue(bank.exposed_domainSeparatorV4() != beginningSeparator);

        bytes32 expectedDomainSeparator = keccak256(
            abi.encode(
                TYPE_HASH,
                HASHED_NAME,
                HASHED_VERSION,
                newChainId,
                address(bank)
            )
        );
        assertEq(bank.exposed_domainSeparatorV4(), expectedDomainSeparator);
    }
}
