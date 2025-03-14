//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
    Stores all relevant information on all projects deployed through Lunar Pump
 */

import "./interfaces/IDatabase.sol";
import "./interfaces/IBondingCurve.sol";
import "./interfaces/ILunarGenerator.sol";
import "./interfaces/ILunarVolumeTracker.sol";
import "./lib/EnumerableSet.sol";
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

    // Lunar Volume Tracker
    address public lunarVolumeTracker;

    // List of all bonded projects
    EnumerableSet.UintSet private bondedProjects;

    // Lits of all pre-bonded projects
    EnumerableSet.UintSet private preBondedProjects;

    // Event emitted when project is created
    event NewTokenCreated(address token, address bondingCurve, uint nonce, bytes projectData);

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
        Sets the lunar volume tracker
     */
    function setLunarVolumeTracker(address _lunarVolumeTracker) external onlyOwner {
        lunarVolumeTracker = _lunarVolumeTracker;
    }

    /**
        Sets the token perma locker
     */
    function setLiquidityPermaLocker(address _liquidityPermaLocker) external onlyOwner {
        liquidityPermaLocker = _liquidityPermaLocker;
    }

    function registerVolume(address user, uint256 amount) external override {
        if (projects[assetToProject[bondingCurveToToken[msg.sender]]].bondingCurve != msg.sender) {
            return;
        }
        if (amount == 0 || user == address(0) || lunarVolumeTracker == address(0)) {
            return;
        }

        // register volume
        ILunarVolumeTracker(lunarVolumeTracker).addVolume(user, amount);
    }

    function bondProject() external override {

        // fetch project from bonding curve
        uint256 projectID = assetToProject[bondingCurveToToken[msg.sender]];
        if (projects[projectID].bondingCurve != msg.sender) {
            return;
        }

        // add to bonded projects
        EnumerableSet.add(bondedProjects, projectID);

        // remove from pre-bonded projects
        EnumerableSet.remove(preBondedProjects, projectID);
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

        // add to list
        EnumerableSet.add(preBondedProjects, projectNonce);

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

    function isBondedByID(uint256 projectID) external view returns (bool) {
        return IBondingCurve(projects[projectID].bondingCurve).isBonded();
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

    function getProjectInfoByToken(address token) public view returns (address, address, string[] memory, address) {
        Project memory project = projects[assetToProject[token]];
        return (project.asset, project.bondingCurve, project.metadata, project.dev);
    }

    function batchGetProjectInfoByTokens(address[] calldata tokens) external view returns (address[] memory, address[] memory, string[][] memory, address[] memory) {
        
        uint len = tokens.length;
        address[] memory assets = new address[](len);
        address[] memory bondingCurves = new address[](len);
        string[][] memory metadata = new string[][](len);
        address[] memory devs = new address[](len);

        for (uint256 i = 0; i < len; i++) {
            ( assets[i], bondingCurves[i], metadata[i], devs[i] ) = getProjectInfoByToken(tokens[i]);
        }

        return (assets, bondingCurves, metadata, devs);
    }

    function batchGetProjectInfo(uint256[] calldata projectIDs) public view returns (address[] memory, address[] memory, string[][] memory, address[] memory) {
        
        uint len = projectIDs.length;
        address[] memory assets = new address[](len);
        address[] memory bondingCurves = new address[](len);
        string[][] memory metadata = new string[][](len);
        address[] memory devs = new address[](len);

        for (uint256 i = 0; i < len; i++) {
            Project memory project = projects[projectIDs[i]];
            assets[i] = project.asset;
            bondingCurves[i] = project.bondingCurve;
            metadata[i] = project.metadata;
            devs[i] = project.dev;
        }

        return (assets, bondingCurves, metadata, devs);
    }

    function paginateBondedProjectIDs(uint256 startIndex, uint256 endIndex) external view returns (uint256[] memory) {
        if (endIndex > EnumerableSet.length(bondedProjects)) {
            endIndex = EnumerableSet.length(bondedProjects);
        }

        uint256 length = endIndex - startIndex;
        uint256[] memory projectIDs = new uint256[](length);
        for (uint256 i = startIndex; i < endIndex;) {
            projectIDs[i - startIndex] = EnumerableSet.at(bondedProjects, i);
            unchecked { ++i; }
        }
        return projectIDs;
    }

    function paginatePrebondedProjectIDs(uint256 startIndex, uint256 endIndex) public view returns (uint256[] memory) {
        if (endIndex > EnumerableSet.length(preBondedProjects)) {
            endIndex = EnumerableSet.length(preBondedProjects);
        }

        uint256 length = endIndex - startIndex;
        uint256[] memory projectIDs = new uint256[](length);
        for (uint256 i = startIndex; i < endIndex;) {
            projectIDs[i - startIndex] = EnumerableSet.at(preBondedProjects, i);
            unchecked { ++i; }
        }
        return projectIDs;
    }

    function paginatePrebondedProjects(uint256 startIndex, uint256 endIndex) external view returns(address[] memory, address[] memory, string[][] memory, address[] memory) {
        uint256[] memory projectIDs = paginatePrebondedProjectIDs(startIndex, endIndex);

        uint len = projectIDs.length;
        address[] memory assets = new address[](len);
        address[] memory bondingCurves = new address[](len);
        string[][] memory metadata = new string[][](len);
        address[] memory devs = new address[](len);

        for (uint256 i = 0; i < len; i++) {
            Project memory project = projects[projectIDs[i]];
            assets[i] = project.asset;
            bondingCurves[i] = project.bondingCurve;
            metadata[i] = project.metadata;
            devs[i] = project.dev;
        }

        return (assets, bondingCurves, metadata, devs);
    }

    function numPrebondedProjects() external view returns (uint256) {
        return EnumerableSet.length(preBondedProjects);
    }

    function numBondedProjects() external view returns (uint256) {
        return EnumerableSet.length(bondedProjects);
    }
}