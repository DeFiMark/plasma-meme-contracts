//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./lib/Ownable.sol";
import "./interfaces/IHigherVolumeTracker.sol";

contract HigherVolumeTracker is IHigherVolumeTracker, Ownable {

    // Database contract
    address public database;

    // Maps a user to volume bet on platform
    mapping ( address => uint256 ) public volumeFor;

    // Maps a token to volume bet on platform
    mapping ( address => uint256 ) public volumeForToken;

    // Total Volume
    uint256 public totalVolume;

    // List of all users who have contributed volume
    address[] public allUsers;

    // Data needed for token to display on scanners
    string public constant name = "PM Volume";
    string public constant symbol = "PMVOL";
    uint8 public constant decimals = 18;
    event Transfer(address indexed from, address indexed to, uint256 value);
    event TokenVolume(address indexed token, address indexed user, uint256 amount);

    constructor(address _database) {
        database = _database;
    }

    function setDatabase(address _database) external onlyOwner {
        database = _database;
    }

    function addVolume(address user, address token, uint256 amount) external override {
        require(msg.sender == database, "HigherVolumeTracker: Only Database can call this function");
        
        // if new user, push to list
        if (volumeFor[user] == 0) {
            allUsers.push(user);
        }

        // add to user volume
        unchecked {
            volumeFor[user] += amount;
            volumeForToken[token] += amount;
            totalVolume += amount;
        }

        // emit transfer
        emit Transfer(address(0), user, amount);
    }

    function totalSupply() external view returns (uint256) {
        return totalVolume;
    }

    function balanceOf(address user) external view returns (uint256) {
        return volumeFor[user];
    }

    function numUsers() external view returns (uint256) {
        return allUsers.length;
    }

    function paginateUsersAndVolumes(uint256 startIndex, uint256 endIndex) external view returns(
        address[] memory users,
        uint256[] memory volumes
    ) {
        if (endIndex > allUsers.length) {
            endIndex = allUsers.length;
        }

        uint256 length = endIndex - startIndex;
        users = new address[](length);
        volumes = new uint256[](length);
        for (uint256 i = startIndex; i < endIndex;) {
            users[i - startIndex] = allUsers[i];
            volumes[i - startIndex] = volumeFor[allUsers[i]];
            unchecked { ++i; }
        }
    }

    function fetchVolumes(address[] calldata users) external view returns (uint256[] memory) {
        uint256[] memory volumes = new uint256[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            volumes[i] = volumeFor[users[i]];
        }
        return volumes;
    }

    function batchVolumesForTokens(address[] calldata tokens) external view returns (uint256[] memory) {
        uint256[] memory volumes = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            volumes[i] = volumeForToken[tokens[i]];
        }
        return volumes;
    }

    function paginateUsers(uint256 startIndex, uint256 endIndex) external view returns (address[] memory) {
        if (endIndex > allUsers.length) {
            endIndex = allUsers.length;
        }

        uint256 length = endIndex - startIndex;
        address[] memory users = new address[](length);
        for (uint256 i = startIndex; i < endIndex;) {
            users[i - startIndex] = allUsers[i];
            unchecked { ++i; }
        }
        return users;
    }
}