//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./IERC20.sol";

interface IHigherPumpToken is IERC20 {

    function bondingCurveTransferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function __init__(bytes calldata payload, string calldata name, string calldata symbol, address bondingCurve_) external;
}