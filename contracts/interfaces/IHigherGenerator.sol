//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IHigherGenerator {
    function generateProject(bytes calldata tokenPayload, bytes calldata bondingCurvePayload, address liquidityAdder) external returns (address token, address bondingCurve);
}