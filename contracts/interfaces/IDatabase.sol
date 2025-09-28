//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IDatabase {
    function isBonded(address token) external view returns (bool);
    function isHigherPumpToken(address token) external view returns (bool);
    function getHigherPumpTokenMasterCopy() external view returns (address);
    function getBondingCurveMasterCopy() external view returns (address);
    function getBondingCurveForToken(address token) external view returns (address);
    function getLiquidityLocker() external view returns (address);
    function getFeeRecipient() external view returns (address);
    function bondProject() external;
    function registerVolume(address token, address user, uint256 amount) external;
    function getHigherPumpGenerator() external view returns (address);
    function owner() external view returns (address);
    function getProjectDev(address token) external view returns (address);
    function addDevFee(address dev) external payable;
}