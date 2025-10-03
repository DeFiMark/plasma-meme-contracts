//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./lib/TransferHelper.sol";
import "./interfaces/IERC20.sol";

contract Airdrop {

    function batchTransfer(address token, address[] calldata recipients, uint256[] calldata amounts) external {
        uint256 len = recipients.length;
        for (uint256 i = 0; i < len;) {
            TransferHelper.safeTransferFrom(token, msg.sender, recipients[i], amounts[i]);
            unchecked { ++i; }
        }
    }

    function sumAmounts(uint256[] calldata amounts) external pure returns (uint256 sum) {
        uint256 len = amounts.length;
        for (uint256 i = 0; i < len;) {
            sum += amounts[i];
            unchecked { ++i; }
        }
    }

    function getDecimals(address token) external view returns (uint256) {
        return IERC20(token).decimals();
    }

}