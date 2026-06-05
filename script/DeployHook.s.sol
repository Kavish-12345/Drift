// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";
import {DriftHook} from "../src/DriftHook.sol";

contract DeployHook is Script {
    address constant CREATE2_PROXY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    uint160 constant FLAGS = uint160(
        Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG
    );

    function run() external {
        address poolManager = vm.envAddress("POOL_MANAGER");
        uint256 pk = vm.envUint("SEPOLIA_PK");

        console.log("Mining hook salt...");
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_PROXY,
            FLAGS,
            type(DriftHook).creationCode,
            abi.encode(poolManager)
        );
        console.log("Hook address found:", hookAddress);

        vm.startBroadcast(pk);
        DriftHook hook = new DriftHook{salt: salt}(IPoolManager(poolManager));
        vm.stopBroadcast();

        require(address(hook) == hookAddress, "Hook address mismatch");
        console.log("SUCCESS - DriftHook deployed:", address(hook));
        console.log("Add to .env: HOOK_ADDRESS=", address(hook));
    }
}
