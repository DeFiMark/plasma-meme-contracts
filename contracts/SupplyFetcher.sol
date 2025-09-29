//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./interfaces/IERC20.sol";
import "./interfaces/IDatabase.sol";

contract SupplyFetcher {
    function getSuppliesInCurve(address database, address[] calldata tokens) public view returns (uint256[] memory supplies, string[] memory names, string[] memory symbols) {
        uint256 length = tokens.length;
        supplies = new uint256[](length);
        names = new string[](length);
        symbols = new string[](length);

        for (uint i = 0; i < length;) {
            address token = tokens[i];
            supplies[i] = IERC20(token).balanceOf(IDatabase(database).getBondingCurveForToken(token));
            names[i] = IERC20(token).name();
            symbols[i] = IERC20(token).symbol();
            unchecked { ++i; }
        }
        return (supplies, names, symbols);
    }
}