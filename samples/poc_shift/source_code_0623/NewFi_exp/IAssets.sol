// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IAssets {
    function asset(
        address user,
        uint pid,
        address token
    ) external view returns (uint256);

    function plusAlone(
        address user,
		uint pid,
		address token,
		uint amount
    ) external;

    function reduceAlone(
        address user,
		uint pid,
		address token,
		uint amount
    ) external;
}