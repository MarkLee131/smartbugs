// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface ICompute {
    function sqrtRatioAtTick(int24 tick) external pure returns (uint160 sqrtPriceX96);
    function tickAtSqrtRatio(uint160 sqrtPriceX96) external pure returns (int24 tick);

    function getLiquidityForAmounts(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0,
        uint256 amount1
    ) external pure returns (uint128 liquidity);

    function getAmountsForLiquidity(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) external pure returns (uint256 amount0, uint256 amount1);
}