//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
    Stores all relevant information on all projects deployed through Lunar Pump
 */

import "./interfaces/IDatabase.sol";
import "./interfaces/IBondingCurve.sol";
import "./interfaces/ILunarGenerator.sol";
import "./lib/Ownable.sol";
import "./lib/TransferHelper.sol";

contract LunarDatabase is IDatabase, Ownable {

    // Project struct
    struct Project {
        address asset;
        address bondingCurve;
        string[] metadata; // social links, description, imageUrl
        address dev;
    }

    // Mapping of project nonce to project
    mapping (uint256 => Project) public projects;

    // Mapping of asset to project nonce
    mapping ( address => uint256 ) public assetToProject;

    // Maps a bonding curve to a token
    mapping ( address => address ) public bondingCurveToToken;

    // Maps a user to volume bet on platform
    mapping ( address => uint256 ) public volumeFor;

    // Total Volume
    uint256 public totalVolume;

    // List of all users who have contributed volume
    address[] public allUsers;

    // Master copy of the LunarPumpToken
    address internal lunarPumpTokenMasterCopy;

    // Master copy of the LunarPumpBondingCurve
    address internal lunarPumpBondingCurveMasterCopy;

    // LunarPumpGenerator
    address internal lunarPumpGenerator;

    // Launch fee
    uint256 public launchFee;

    // Fee recipient
    address private feeRecipient;

    // Project nonce
    uint256 public projectNonce = 1;

    // Liquidity adder contract
    address public liquidityAdder;

    // Token Perma Locker
    address public liquidityPermaLocker;

    // Data needed for token to display on scanners
    string public constant name = "LunarVolume";
    string public constant symbol = "LVolume";
    uint8 public constant decimals = 18;

    // Event emitted when project is created
    event NewTokenCreated(address token, address bondingCurve, uint nonce, bytes projectData);
    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor() {
        launchFee = 0.01 ether;
        feeRecipient = msg.sender;
    }

    /**
        Sets the address of the LunarPumpTokenMasterCopy
     */
    function setLunarPumpTokenMasterCopy(address _lunarPumpTokenMasterCopy) external onlyOwner {
        lunarPumpTokenMasterCopy = _lunarPumpTokenMasterCopy;
    }

    /**
        Sets the address of the LunarPumpBondingCurveMasterCopy
     */
    function setLunarPumpBondingCurveMasterCopy(address _lunarPumpBondingCurveMasterCopy) external onlyOwner {
        lunarPumpBondingCurveMasterCopy = _lunarPumpBondingCurveMasterCopy;
    }

    /**
        Sets the address of the LunarPumpGenerator
     */
    function setLunarPumpGenerator(address _lunarPumpGenerator) external onlyOwner {
        lunarPumpGenerator = _lunarPumpGenerator;
    }

    /**
        Sets the launch fee
     */
    function setLaunchFee(uint256 _launchFee) external onlyOwner {
        launchFee = _launchFee;
    }

    /**
        Sets the fee recipient
     */
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        feeRecipient = _feeRecipient;
    }

    /**
        Sets the liquidity adder
     */
    function setLiquidityAdder(address _liquidityAdder) external onlyOwner {
        liquidityAdder = _liquidityAdder;
    }

    /**
        Sets the token perma locker
     */
    function setLiquidityPermaLocker(address _liquidityPermaLocker) external onlyOwner {
        liquidityPermaLocker = _liquidityPermaLocker;
    }

    function registerVolume(address user, uint256 amount) external {
        if (projects[bondingCurveToToken[msg.sender]].bondingCurve != msg.sender) {
            return;
        }
        if (amount == 0 || user == address(0)) {
            return;
        }

        // if new user, push to list
        if (volumeFor[user] == 0) {
            allUsers.push(user);
        }

        // add to user volume
        unchecked {
            volumeFor[user] += amount;
            totalVolume += amount;
        }

        // emit transfer
        emit Transfer(address(0), user, amount);
    }

    function launchProject(
        string[] calldata metadata,
        bytes calldata tokenPayload,
        bytes calldata bondingCurvePayload
    ) external payable {
        // ensure fees are taken
        require(
            msg.value >= launchFee,
            'Insufficient Fee'
        );

        // send fee to fee recipient
        TransferHelper.safeTransferETH(feeRecipient, launchFee);

        // generate token and bonding curve
        (address token, address bondingCurve) = ILunarGenerator(lunarPumpGenerator).generateProject(tokenPayload, bondingCurvePayload, liquidityAdder);

        // store project
        projects[projectNonce] = Project({
            asset: token,
            bondingCurve: bondingCurve,
            metadata: metadata,
            dev: tx.origin
        });

        // store asset to project mapping
        assetToProject[token] = projectNonce;

        // store bonding curve to token launch
        bondingCurveToToken[bondingCurve] = token;

        // emit new event
        emit NewTokenCreated(token, bondingCurve, projectNonce, abi.encode(metadata, tokenPayload, bondingCurvePayload));

        // increment nonce
        unchecked {
            ++projectNonce;
        }

        // if user supplied more value than launch fee, use it to buy tokens for them
        if (msg.value > launchFee) {
            IBondingCurve(bondingCurve).buyTokens{value: msg.value - launchFee}(msg.sender, 0);
        }
    }

    function getLunarPumpTokenMasterCopy() external view override returns (address) {
        return lunarPumpTokenMasterCopy;
    }

    function getBondingCurveMasterCopy() external view override returns (address) {
        return lunarPumpBondingCurveMasterCopy;
    }

    function getLunarPumpGenerator() external view returns (address) {
        return lunarPumpGenerator;
    }

    function isBonded(address token) external view override returns (bool) {
        return IBondingCurve(projects[assetToProject[token]].bondingCurve).isBonded();
    }

    function isLunarPumpToken(address token) external view override returns (bool) {
        return assetToProject[token] != 0 && projects[assetToProject[token]].asset == token;
    }

    function getBondingCurveForToken(address token) external view override returns (address) {
        return projects[assetToProject[token]].bondingCurve;
    }

    function getProjectMetadata(address token) external view returns (string[] memory) {
        return projects[assetToProject[token]].metadata;
    }

    function getProjectDev(address token) external view returns (address) {
        return projects[assetToProject[token]].dev;
    }

    function getLiquidityLocker() external view override returns (address) {
        return liquidityPermaLocker;
    }

    function getFeeRecipient() external view override returns (address) {
        return feeRecipient;
    }

    function balanceOf(address user) external view returns (uint256) {
        return volumeFor[user];
    }

    function totalSupply() external view returns (uint256) {
        return totalVolume;
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
}