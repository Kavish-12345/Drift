// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IDriftHook {
    struct EntrySnapshot {
        uint160 sqrtPriceX96;
        int24   tickLower;
        int24   tickUpper;
        uint128 liquidity;
        uint256 amount0;
        uint256 amount1;
    }

    function snapshots(uint256 tokenId) external view returns (
        uint160 sqrtPriceX96,
        int24   tickLower,
        int24   tickUpper,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    function getPositionCount() external view returns (uint256);
    function positionList(uint256 index) external view returns (uint256);
}