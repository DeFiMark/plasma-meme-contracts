//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ILunarVolumeTracker {
    function addVolume(address user, uint256 volume) external;
}