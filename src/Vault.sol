// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "openzeppelin-contracts/security/Pausable.sol";
import {IVault} from "./interfaces/IVault.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import "./Constants.sol";

contract Vault is Pausable, AccessControl, IVault {
    using SafeERC20 for IERC20;
    event Transfer(address to, address token, uint256 amount);

    event NewBank(address indexed newBank);

    modifier onlyAdmin() {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    modifier onlyBank() {
        _checkRole(BANK_ROLE);
        _;
    }

    /// @inheritdoc IVault
    function pause() external override onlyAdmin {
        _pause();
    }

    /// @inheritdoc IVault
    function unpause() external override onlyAdmin {
        _unpause();
    }

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        // pause the contract
        _pause();
    }

    /// @inheritdoc IVault
    function setBank(address _bank) external override whenPaused onlyAdmin {
        require(_bank != address(0), "Vault::bank=address(0)");
        _setupRole(BANK_ROLE, _bank);
        emit NewBank(_bank);
    }

    /// @inheritdoc IVault
    function transfer(
        address _token,
        address _to,
        uint256 _amount
    ) external override whenNotPaused onlyBank {
        require(_to != address(0), "Vault::to=address(0)");
        if (_token == ETH_ADDRESS) {
            payable(_to).transfer(_amount);
        } else {
            // verifies that he target address contains contract code and also asserts for success in the low-level call.
            IERC20(_token).safeTransfer(_to, _amount);
        }
        emit Transfer(_to, _token, _amount);
    }

    // Invest Token from vault to other protocol to earn yield
    /*  function investToken(
        address _token,
        uint256 _amount,
        address _to
    ) external override onlyAdmin {
        require(_to != address(0), "Vault::to=address(0)");
        // check if to is an allowed protocol
        IERC20(_token).safeTransfer(_to, _amount);
        // we should keep track of the invested amount

    } */
}
