// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console} from "forge-std/Script.sol";
import {DriftRegistry} from "../src/DriftRegistry.sol";

contract WireAndFund is Script {
    function run() external {
        address payable registryAddress  = payable(vm.envAddress("REGISTRY_ADDRESS"));
        address reactiveAddress  = vm.envAddress("REACTIVE_ADDRESS");
        uint256 pk               = vm.envUint("SEPOLIA_PK");

        vm.startBroadcast(pk);
        DriftRegistry registry = DriftRegistry(registryAddress);
        registry.initialize(reactiveAddress);
        console.log("Registry initialized with reactive:", reactiveAddress);

        // Fund registry for callback gas
        (bool ok,) = registryAddress.call{value: 0.1 ether}("");
        require(ok, "Fund registry failed");
        console.log("Registry funded: 0.1 ETH");
        vm.stopBroadcast();
    }
}
