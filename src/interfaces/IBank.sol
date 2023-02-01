// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

/**
 * @title Bank interface
 */
interface IBank {
    /**
     * @dev pause the contract
     */
    function pause() external;

    /**
     * @dev un pause the contract
     */
    function unpause() external;

    /*
     * @dev check if forwarder is trusted
     * @param _forwarder forwarder address
     */
    function isTrustedForwarder(address _forwarder) external returns (bool);

    ///@dev deposits token into the vault
    ///@param token the address of the token to deposit
    ///@param amount the amount of token to deposit
    function deposit(address token, uint256 amount) external;

    ///@dev deposits token into the vault with a permit signature
    ///     can save gas with tokens like USDC
    ///@param token the address of the token to deposit
    ///@param amount the amount of token to deposit
    function depositWithPermit(
        address token,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    ///@dev withdraws token from the vault
    ///@param token the address of the token to withdraw
    ///@param recipient the address to send the token to
    ///@param amount the amount of token to withdraw
    function withdraw(
        address token,
        address recipient,
        uint256 amount
    ) external;

    ///@dev returns the balance of a token for an account
    ///@param token the address of the token
    ///@param account the address of the account
    ///@return the balance of the token for the account
    function balanceOf(
        address token,
        address account
    ) external returns (uint256);

    ///@dev set the new Trusted Forwarder used in meta tx
    ///@param newForwarder the address of the new forwarder
    function setTrustedForwarder(address newForwarder) external;

    ///@dev add a new token to the list of allowed tokens
    ///@param newToken the address of the new token
    function addAllowedToken(address newToken) external;

    ///@dev remove a token from the list of allowed tokens
    ///@param token the address of the token to remove
    function removeAllowedToken(address token) external;
}
