//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IHigherVolumeTracker {
    function addVolume(address user, address token, uint256 volume) external;
}