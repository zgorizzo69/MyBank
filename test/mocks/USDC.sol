// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;
import "openzeppelin-contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "openzeppelin-contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract USDC is ERC20PresetMinterPauser, ERC20Permit {
    constructor()
        payable
        ERC20PresetMinterPauser("USD Coin", "USDC")
        ERC20Permit("USD Coin")
    {} // solhint-disable-line no-empty-blocks

    function mint(address to, uint256 amount) public override {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20PresetMinterPauser) {
        super._beforeTokenTransfer(from, to, amount);
    }
}
