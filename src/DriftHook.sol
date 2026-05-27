// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {Position} from "v4-core/src/libraries/Position.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/src/types/PoolOperation.sol";

contract DriftHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    struct EntrySnapshot {
        uint160 sqrtPriceX96;
        int24   tickLower;
        int24   tickUpper;
        uint128 liquidity;
        uint256 amount0;
        uint256 amount1;
    }

    mapping(uint256 => EntrySnapshot) public snapshots;
    mapping(uint256 => bool) public activePositions;
    uint256[] public positionList;

    event SwapObserved(
        PoolId indexed poolId,
        uint160 sqrtPriceX96,
        int24   currentTick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint32  timestamp
    );

    event PositionSnapshotted(
        uint256 indexed tokenId,
        uint160 sqrtPriceX96,
        int24   tickLower,
        int24   tickUpper,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    constructor(IPoolManager _manager) BaseHook(_manager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize:                false,
            afterInitialize:                 false,
            beforeAddLiquidity:              false,
            afterAddLiquidity:               true,
            beforeRemoveLiquidity:           false,
            afterRemoveLiquidity:            false,
            beforeSwap:                      false,
            afterSwap:                       true,
            beforeDonate:                    false,
            afterDonate:                     false,
            beforeSwapReturnDelta:           false,
            afterSwapReturnDelta:            false,
            afterAddLiquidityReturnDelta:    false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _afterAddLiquidity(
        address,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata hookData
    ) internal override returns (bytes4, BalanceDelta) {
        uint256 tokenId = abi.decode(hookData, (uint256));

        (uint160 sqrtPriceX96, , , ) = poolManager.getSlot0(key.toId());

        uint128 liq;
        {
            bytes32 positionId = Position.calculatePositionKey(
                address(this),
                params.tickLower,
                params.tickUpper,
                params.salt
            );
            liq = poolManager.getPositionLiquidity(key.toId(), positionId);
        }

        uint256 amount0;
        uint256 amount1;
        {
            amount0 = delta.amount0() < 0
                ? uint256(uint128(-delta.amount0()))
                : uint256(uint128(delta.amount0()));
            amount1 = delta.amount1() < 0
                ? uint256(uint128(-delta.amount1()))
                : uint256(uint128(delta.amount1()));
        }

        snapshots[tokenId] = EntrySnapshot({
            sqrtPriceX96: sqrtPriceX96,
            tickLower:     params.tickLower,
            tickUpper:     params.tickUpper,
            liquidity:     liq,
            amount0:       amount0,
            amount1:       amount1
        });

        if (!activePositions[tokenId]) {
            activePositions[tokenId] = true;
            positionList.push(tokenId);
        }

        emit PositionSnapshotted(
            tokenId, sqrtPriceX96,
            params.tickLower, params.tickUpper,
            liq, amount0, amount1
        );

        return (BaseHook.afterAddLiquidity.selector, delta);
    }

    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        (uint160 sqrtPriceX96, int24 currentTick, , ) = poolManager.getSlot0(key.toId());

        (uint256 fg0, uint256 fg1) = poolManager.getFeeGrowthGlobals(key.toId());

        emit SwapObserved(
            key.toId(),
            sqrtPriceX96,
            currentTick,
            fg0,
            fg1,
            uint32(block.timestamp)
        );

        return (BaseHook.afterSwap.selector, 0);
    }

    function getSnapshot(uint256 tokenId) external view returns (EntrySnapshot memory) {
        return snapshots[tokenId];
    }

    function getPositionCount() external view returns (uint256) {
        return positionList.length;
    }
}