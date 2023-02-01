// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ContextUpgradeable, ERC2771ContextUpgradeable} from "openzeppelin-contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IBank} from "./interfaces/IBank.sol";
import {Vault} from "./Vault.sol";
import {EIP712Upgradeable} from "openzeppelin-contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import {IERC20Permit} from "openzeppelin-contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract MyBank is
    Initializable,
    IBank,
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC2771ContextUpgradeable,
    EIP712Upgradeable
{
    // Using SafeERC20Upgradeable library for IDebtToken
    using SafeERC20Upgradeable for IERC20;

    event Deposit(address indexed token, address indexed from, uint256 amount);
    event Withdraw(address indexed token, address indexed to, uint256 amount);
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    mapping(address => bool) public allowedTokens;
    mapping(address => mapping(address => uint)) private balances;
    uint256 internal _version;
    Vault public vault;
    address public trustedForwarder;

    constructor() payable ERC2771ContextUpgradeable(address(0)) {
        /* 
        An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
        contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
        the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
        Indeed an attacker can initialize it and appoint themselves as upgrade administrators. 
        This allows them to call the upgradeToAndCall  function on the implementation directly,
        instead of on the proxy, and use it to DELEGATECALL into a malicious contract with a SELFDESTRUCT operation.
      */
        _disableInitializers();
    }

    ///@dev no constructor in upgradable contracts. Instead we have initializers
    ///@param _vault the address of the vault
    function initialize(
        address _vault,
        address _trustedForwarder,
        address[] calldata _allowedTokens
    ) public initializer {
        // Initialize ReentrancyGuard
        __ReentrancyGuard_init_unchained();

        // Initialize pausable. Set pause to false;
        __Pausable_init();

        // Initialize EIP712
        __EIP712_init("MyBank", "0.0.1");

        ///@dev as there is no constructor, we need to initialise the OwnableUpgradeable explicitly
        __Ownable_init();

        vault = Vault(_vault);
        trustedForwarder = _trustedForwarder;

        for (uint256 i; i < _allowedTokens.length; ++i)
            allowedTokens[_allowedTokens[i]] = true;
        _version = 1;
        // set to pause after init
        _pause();
    }

    modifier onlyAutorizedToken(address token) {
        require(allowedTokens[token], "token!allowed");
        _;
    }

    ///@dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// @inheritdoc IBank
    function pause() external override onlyOwner {
        _pause();
    }

    /// @inheritdoc IBank
    function unpause() external override onlyOwner {
        _unpause();
    }

    /// @inheritdoc IBank
    function setTrustedForwarder(
        address newForwarder
    ) external override onlyOwner {
        require(newForwarder != address(0), "forwarder=0");
        trustedForwarder = newForwarder;
    }

    /// @inheritdoc IBank
    function addAllowedToken(address newToken) external override onlyOwner {
        require(newToken != address(0), "newToken=0");
        allowedTokens[newToken] = true;
        emit TokenAdded(newToken);
    }

    /// @inheritdoc IBank
    function removeAllowedToken(address token) external override onlyOwner {
        require(allowedTokens[token] == true, "tokenNotAllowed");
        allowedTokens[token] = false;
        emit TokenRemoved(token);
    }

    /// @inheritdoc IBank
    function isTrustedForwarder(
        address _forwarder
    ) public view override(ERC2771ContextUpgradeable, IBank) returns (bool) {
        return trustedForwarder == _forwarder;
    }

    /*******************************************************************************
     * ------------------------------INTERNAL VIEWS------------------------------- *
     *******************************************************************************/
    /// @dev This is same as ERC2771ContextUpgradeable._msgSender()
    function _msgSender()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        // We want to use the _msgSender() implementation of ERC2771ContextUpgradeable
        sender = super._msgSender();
    }

    /// @dev This is same as ERC2771ContextUpgradeable._msgData()
    function _msgData()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        // We want to use the _msgData() implementation of ERC2771ContextUpgradeable
        return super._msgData();
    }

    /// @inheritdoc IBank
    function deposit(
        address token,
        uint256 amount
    ) public override nonReentrant whenNotPaused onlyAutorizedToken(token) {
        require(amount > 0, "amount=0");
        address sender = _msgSender();
        IERC20(token).transferFrom(sender, address(vault), amount);
        balances[token][sender] += amount;
        emit Deposit(token, sender, amount);
    }

    /// @inheritdoc IBank
    function depositWithPermit(
        address token,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public override nonReentrant whenNotPaused onlyAutorizedToken(token) {
        require(amount > 0, "amount=0");
        address sender = _msgSender();
        // TODO (EIP165) check token supports IERC20Permit
        IERC20Permit(token).permit(
            sender,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );
        IERC20(token).transferFrom(sender, address(vault), amount);
        balances[token][sender] += amount;
        emit Deposit(token, sender, amount);
    }

    /// @inheritdoc IBank
    function withdraw(
        address token,
        address recipient,
        uint256 amount
    ) public override nonReentrant whenNotPaused onlyAutorizedToken(token) {
        address sender = _msgSender();
        require(balances[token][sender] >= amount, "balance<amount");

        balances[token][sender] -= amount;
        vault.transfer(token, recipient, amount);
        emit Withdraw(token, recipient, amount);
    }

    /// @inheritdoc IBank
    function balanceOf(
        address token,
        address account
    ) public view override returns (uint256) {
        return balances[token][account];
    }
}
