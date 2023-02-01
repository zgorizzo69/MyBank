// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

/**
 * @title AccessControl interface
 */
interface IVault {
    /**
     * @dev pause the contract
     */
    function pause() external;

    /**
     * @dev un pause the contract
     */
    function unpause() external;

    ///@dev transfers token from the vault
    ///@param _token the address of the token to transfer
    ///@param _to the address to send the token to
    ///@param _amount the amount of token to transfer
    function transfer(address _token, address _to, uint256 _amount) external;

    ///@dev sets the bank address
    ///@param _bank the address of the bank
    function setBank(address _bank) external;
}
