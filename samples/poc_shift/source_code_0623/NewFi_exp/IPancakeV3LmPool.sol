// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IPancakeV3LmPool {
    function masterChef() external view returns (address);
}