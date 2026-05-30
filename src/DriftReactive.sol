// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AbstractReactive} from "reactive-lib/base/AbstractReactive.sol";
import {IReactive} from "reactive-lib/interfaces/IReactive.sol";
import {ISystemContract} from "reactive-lib/interfaces/ISystemContract.sol";
import {FullMath} from "v4-core/src/libraries/FullMath.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {DriftLiquidityAmounts} from "./libraries/DriftLiquidityAmounts.sol";
import {IDriftHook} from "./interfaces/IDriftHook.sol";

contract DriftReactive is AbstractReactive {
    uint64  private constant CALLBACK_GAS_LIMIT = 300_000;

    // SwapObserved(PoolId,uint160,int24,uint256,uint256,uint32)
    uint256 private constant SWAP_OBSERVED_TOPIC0 =
        uint256(keccak256("SwapObserved(bytes32,uint160,int24,uint256,uint256,uint32)"));

    uint256 public immutable originChainId; // Sepolia chain ID 
    address public immutable driftHook; // DriftHook on Sepolia
    address public immutable driftRegistry; // DriftRegistry on Sepolia

    constructor(
        uint256 originChainId_,
        address driftHook_,
        address driftRegistry_
    ) {
        originChainId = originChainId_;
        driftHook     = driftHook_;
        driftRegistry = driftRegistry_;

        SYSTEM.subscribe(
            originChainId_,
            driftHook_,
            SWAP_OBSERVED_TOPIC0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }

    function react (IReactive.LogRecord calldata log_) external onlySystem {
        (
        uint160 sqrtPriceX96,
        int24  currentTick,
        ,
        ,
        ) = abi.decode(log_.data, (uint160,int24,uint256,uint256,uint32));

        uint256 positionCount = IDriftHook(driftHook).getPositionCount();

        for (uint256 i = 0; i < positionCount; i++) {
            uint256 tokenId = IDriftHook(driftHook).positionList(i);
            _processPosition(tokenId, sqrtPriceX96, currentTick);
        }
    }

    function _processPosition(
        uint256 tokenId, 
        uint160 sqrtPriceX96,
        int24   currentTick
    ) internal {
        (
            uint160 sqrtP0,
            int24   tickLower,
            int24   tickUpper,
            uint128 liquidity,
            uint256 amount0Entry,
            uint256 amount1Entry
        ) = IDriftHook(driftHook).snapshots(tokenId);

        if (sqrtP0 == 0 || liquidity == 0) return;

        int16 ilBps = _computeILBps(
            sqrtPriceX96,
            tickLower,
            tickUpper,
            liquidity,
            amount0Entry,
            amount1Entry
        );

        bytes memory payload = abi.encodeWithSignature(
            "updateIL(address,uint256,int16)",
            address(0),
            tokenId,
            ilBps
        );

        SYSTEM.requestCallbackV_1_0(
            ISystemContract.CallbackConfiguration_V_1_0({
                chainId: originChainId,
                recipient: driftRegistry,
                gasLimit: CALLBACK_GAS_LIMIT,
                payload: payload
            })
        );
    }

     function _computeILBps(
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 amount0Entry,
        uint256 amount1Entry
    ) internal pure returns (int16) {
        uint160 sqrtPa = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPb = TickMath.getSqrtPriceAtTick(tickUpper);

        (uint256 amount0Now, uint256 amount1Now) = DriftLiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, sqrtPa, sqrtPb, liquidity
        );

        uint256 priceX128 = FullMath.mulDiv(
            uint256(sqrtPriceX96),
            uint256(sqrtPriceX96),
            1 << 64
        );

        uint256 hodlValue = FullMath.mulDiv(amount0Entry, priceX128, 1 << 128)
                          + amount1Entry;

        uint256 lpValue = FullMath.mulDiv(amount0Now, priceX128, 1 << 128)
                        + amount1Now;

        if (lpValue >= hodlValue) return 0;

        uint256 lossX10000 = FullMath.mulDiv(
            hodlValue - lpValue,
            10000,
            hodlValue
        );

        if (lossX10000 > 10000) lossX10000 = 10000;

        return -int16(uint16(lossX10000));
    }
}