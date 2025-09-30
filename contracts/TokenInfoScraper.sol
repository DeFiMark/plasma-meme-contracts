//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./interfaces/IERC20.sol";

contract TokenInfoScraper {

    function getTokenInfo(address token) external view returns (string memory name, string memory symbol, uint8 decimals) {
        name = IERC20(token).name();
        symbol = IERC20(token).symbol();
        decimals = IERC20(token).decimals();
    }

    function getTokenInfoAndBalance(address token, address account) external view returns (string memory name, string memory symbol, uint8 decimals, uint256 balance) {
        name = IERC20(token).name();
        symbol = IERC20(token).symbol();
        decimals = IERC20(token).decimals();
        balance = IERC20(token).balanceOf(account);
    }

    function batchGetTokenInfo(address[] calldata tokens) external view returns (string[] memory names, string[] memory symbols, uint8[] memory decimals) {
        uint256 length = tokens.length;
        names = new string[](length);
        symbols = new string[](length);
        decimals = new uint8[](length);
        
        for (uint256 i = 0; i < length; i++) {
            names[i] = IERC20(tokens[i]).name();
            symbols[i] = IERC20(tokens[i]).symbol();
            decimals[i] = IERC20(tokens[i]).decimals();
        }
        return (names, symbols, decimals);
    }
}