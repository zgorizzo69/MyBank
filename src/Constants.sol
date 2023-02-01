// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
bytes32 constant BANK_ROLE = keccak256("BANK_ROLE");

bytes32 constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

address constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; // ETH address

// keccak256("Permit(address owner,address spender,
//                   uint256 value,uint256 nonce,uint256 deadline)");
bytes32 constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
