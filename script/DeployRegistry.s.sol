// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console} from "forge-std/Script.sol";
import {DriftRegistry} from "../src/DriftRegistry.sol";

contract DeployRegistry is Script {
    function run() external {
        address callbackProxy = vm.envAddress("REACTIVE_PROXY");
        uint256 pk = vm.envUint("SEPOLIA_PK");

        vm.startBroadcast(pk);
        DriftRegistry registry = new DriftRegistry(payable(callbackProxy));
        vm.stopBroadcast();

        console.log("SUCCESS - DriftRegistry deployed:", address(registry));
        console.log("Add to .env: REGISTRY_ADDRESS=", address(registry));
    }
}
