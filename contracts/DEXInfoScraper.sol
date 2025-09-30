//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./interfaces/IERC20.sol";

interface IHigherFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

contract DEXInfoScraper {

    address public constant WETH = 0x6100E367285b01F48D07953803A2d8dCA5D19873;

    function getTokenInfo(address token, address factory) external view returns (string memory name, string memory symbol, address pair, uint256 amountTokenLP, uint256 amountETHLP) {
        name = IERC20(token).name();
        symbol = IERC20(token).symbol();
        pair = IHigherFactory(factory).getPair(token, WETH);
        amountTokenLP = IERC20(token).balanceOf(pair);
        amountETHLP = IERC20(WETH).balanceOf(pair);
    }

    function batchGetTokenInfo(address[] calldata tokens, address factory) external view returns (string[] memory names, string[] memory symbols, address[] memory pairs, uint256[] memory amountTokenLP, uint256[] memory amountETHLP) {
        uint256 length = tokens.length;
        names = new string[](length);
        symbols = new string[](length);
        pairs = new address[](length);
        amountTokenLP = new uint256[](length);
        amountETHLP = new uint256[](length);
        
        for (uint256 i = 0; i < length; i++) {
            names[i] = IERC20(tokens[i]).name();
            symbols[i] = IERC20(tokens[i]).symbol();
            pairs[i] = IHigherFactory(factory).getPair(tokens[i], WETH);
            amountTokenLP[i] = IERC20(tokens[i]).balanceOf(pairs[i]);
            amountETHLP[i] = IERC20(WETH).balanceOf(pairs[i]);
        }
        return (names, symbols, pairs, amountTokenLP, amountETHLP);
    }
}