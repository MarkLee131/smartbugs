// SPDX-License-Identifier: GPL-2.0-or-later

interface IBaseV1Pair {
    function getAmountOut(uint256 amountIn, address tokenIn)
        external
        view
        returns (uint256);
}