// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";
import {BaseScript} from "./base/BaseScript.sol";
import {DriftHook} from "../src/DriftHook.sol";

contract DeployHookScript is BaseScript {
    function run() public {
        // Drift uses afterAddLiquidity and afterSwap only
        uint160 flags = uint160(
            Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG
        );

        // Mine a salt that produces an address with the correct permission bits
        bytes memory constructorArgs = abi.encode(poolManager);
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_FACTORY,
            flags,
            type(DriftHook).creationCode,
            constructorArgs
        );

        // Deploy DriftHook at the mined address
        vm.startBroadcast();
        DriftHook hook = new DriftHook{salt: salt}(poolManager);
        vm.stopBroadcast();

        require(address(hook) == hookAddress, "DeployHookScript: Hook Address Mismatch");
    }
}