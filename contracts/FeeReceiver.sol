//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IFeeRecipient {

    function takeBondFee(address token) external payable;
    function takeVolumeFee(address token) external payable;

}


contract FeeReceiver is IFeeRecipient {

    address public recipient;

    constructor(address _recipient) {
        recipient = _recipient;
    }

    function takeBondFee(address) external payable override {
        (bool s,) = payable(recipient).call{value: address(this).balance}("");
        require(s);
    }

    function takeVolumeFee(address) external payable override {
        (bool s,) = payable(recipient).call{value: address(this).balance}("");
        require(s);
    }

    receive() external payable {}
}