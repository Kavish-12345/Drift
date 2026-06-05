// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console} from "forge-std/Script.sol";
import {DriftReactive} from "../src/DriftReactive.sol";

contract DeployReactive is Script {
    function run() external {
        address hookAddress      = vm.envAddress("HOOK_ADDRESS");
        address registryAddress  = vm.envAddress("REGISTRY_ADDRESS");
        uint256 pk               = vm.envUint("REACTIVE_PK");

        vm.startBroadcast(pk);
      DriftReactive reactive = new DriftReactive(
    payable(0x8888888888888888888888888888888888888888),
    11155111,
    hookAddress,
    registryAddress
);
        vm.stopBroadcast();

        console.log("SUCCESS - DriftReactive deployed:", address(reactive));
        console.log("Add to .env: REACTIVE_ADDRESS=", address(reactive));
    }
}
