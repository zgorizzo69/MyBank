// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

import {CREATE3Script} from "./base/CREATE3Script.sol";
import {MyBank} from "../src/MyBank.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {Vault} from "../src/Vault.sol";
import "forge-std/console.sol";

contract DeployScript is CREATE3Script {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run()
        external
        returns (
            MyBank bank,
            ERC1967Proxy proxy,
            MockERC20 mockERC20,
            Vault vault
        )
    {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        uint256 param = 123;

        vm.startBroadcast(deployerPrivateKey);

        bank = MyBank(
            create3.deploy(
                getCreate3ContractSalt("MyBank"),
                bytes.concat(type(MyBank).creationCode, abi.encode(param))
            )
        );
        proxy = new ERC1967Proxy(address(bank), "");
        mockERC20 = MockERC20(
            payable(
                create3.deploy(
                    getCreate3ContractSalt("MockERC20"),
                    bytes.concat(
                        type(MockERC20).creationCode,
                        abi.encode("Mock", "MCK", 18)
                    )
                )
            )
        );
        address[] memory allowedTokens = new address[](1);
        allowedTokens[0] = address(mockERC20);
        vault = new Vault();

        MyBank proxiedBank = MyBank(address(proxy));
        proxiedBank.initialize(address(vault), address(0), allowedTokens);
        vault.setBank(address(proxiedBank));
        vault.unpause();
        proxiedBank.unpause();
        vm.stopBroadcast();
    }
}
