//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ILiquidityAdder {
    function bond(address token) external payable;
}