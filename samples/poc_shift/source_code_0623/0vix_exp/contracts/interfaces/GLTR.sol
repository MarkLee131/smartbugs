//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface farm{

    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function harvest(uint256 _pid) external;

    function batchHarvest(uint256[] memory _pids) external;

    function poolLength() external view returns (uint256);

    function deposited(uint256 _pid, address _user) external view returns (uint256);
}
