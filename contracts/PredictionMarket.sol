// //SPDX-License-Identifier: MIT
// pragma solidity 0.8.28;

// import "./lib/TransferHelper.sol";
// import "./lib/Ownable.sol";
// import "./lib/ReentrancyGuard.sol";
// import "./lib/EnumerableSet.sol";
// import "./interfaces/IDatabase.sol";

// /**
//  * @title Prediction Market
//  * @author Higher
//  * @notice Allows users to place bets on whether a token will bond or not
//  * We need to be careful about the odds shifting as the token increases in value
//  * We could either have a short bet window or make bets work similarly to an AMM, so odds can shift and not ruin the experience
//  */
// contract PredictionMarket is Ownable, ReentrancyGuard {

//     IDatabase public immutable database;

//     uint256 public duration = 6 hours;

//     struct MarketBet {
//         EnumerableSet.AddressSet usersFor;
//         EnumerableSet.AddressSet usersAgainst;
//         mapping ( address => uint256 ) userBet;
//         uint256 totalBetsFor;
//         uint256 totalBetsAgainst;
//     }

//     struct Market {
//         MarketBet marketBet;
//         bool hasEnded;
//         uint256 expirationTimestamp;
//     }

//     mapping ( address => Market ) private markets;

//     constructor(address _database) {
//         database = IDatabase(_database);
//     }

//     function placeBet(address token, bool isForBonding) external payable nonReentrant {
//         require(database.isBonded(token) == false, "Token is already bonded");
//         require(markets[token].hasEnded == false, "Market has ended");
        
//         if (markets[token].expirationTimestamp == 0) {
//             // first bet, set expiration timestamp
//             markets[token].expirationTimestamp = block.timestamp + duration;
//         } else {
//             require(markets[token].expirationTimestamp > block.timestamp, "Market has expired");
//         }
//     }

//     function isBonded(address token) external view returns (bool) {
//         return database.isBonded(token);
//     }

// }