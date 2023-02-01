// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./MyBank.sol";

contract MyBankV2 is MyBank {
    ///@dev increments the slices when called
    function increaseVersion() external {
        unchecked {
            _version += 1;
        }
    }

    ///@dev returns the contract version
    function version() external view returns (uint256) {
        return _version;
    }
}
