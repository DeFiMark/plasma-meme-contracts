//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./interfaces/IDatabase.sol";
import "./lib/TransferHelper.sol";
import "./lib/Ownable.sol";
import "./lib/EnumerableSet.sol";
import "./interfaces/IHigherGenerator.sol";

interface IBondingCurve {
    function getVersionNo() external view returns (uint32);
    function isBonded() external view returns (bool);
    function __init__(bytes calldata payload, address token, address liquidityAdder) external;
    function getToken() external view returns (address);
    function buyTokens(address recipient, uint256 minOut) external payable returns (uint256 tokensBought);
}

interface IHigherVolumeTracker {
    function addVolume(address user, address token, uint256 volume) external;
}

contract HigherDatabase is IDatabase, Ownable {

    // Project struct
    struct Project {
        address asset;
        address bondingCurve;
        string[] metadata; // social links, description, imageUrl
        string name;
        string symbol;
        address dev;
        address creatorAddress;
        uint256 launchTime;
    }

    // Mapping of project nonce to project
    mapping (uint256 => Project) public projects;

    // Mapping of asset to project nonce
    mapping ( address => uint256 ) public assetToProject;

    // Maps a bonding curve to a token
    mapping ( address => address ) public bondingCurveToToken;

    // Maps an address to a list of projects they have launched
    mapping ( address => uint256[] ) public allDevProjects;

    // mapping for contracts that can register volume
    mapping ( address => bool ) public canRegisterVolume;

    // dev fee struct
    struct DevFee {
        uint256 claimedDevFees;
        uint256 pendingDevFees;
    }

    // Maps a dev to their total dev fees
    mapping ( address => DevFee ) public devFees;

    // Master copy of the HigherPumpToken
    address internal HigherPumpTokenMasterCopy;

    // Master copy of the HigherPumpBondingCurve
    address internal HigherPumpBondingCurveMasterCopy;

    // HigherPumpGenerator
    address internal HigherPumpGenerator;

    // Launch fee
    uint256 public launchFee;

    // Fee recipient
    address private feeRecipient;

    // Project nonce
    uint256 public projectNonce = 1;

    // Liquidity adder contract
    address public liquidityAdder;

    // Token Perma Locker
    address public constant liquidityPermaLocker = 0x000000000000000000000000000000000000dEaD;

    // Higher Volume Tracker
    address public HigherVolumeTracker;

    // List of all bonded projects
    EnumerableSet.UintSet private bondedProjects;

    // Lits of all pre-bonded projects
    EnumerableSet.UintSet private preBondedProjects;

    // Pauses all new launches
    bool public paused;

    // Event emitted when project is created
    event NewTokenCreated(address indexed dev, address token, address bondingCurve, string name, string symbol);
    event Bonded(address token);

    constructor() {
        launchFee = 1 ether;
        feeRecipient = msg.sender;
    }

    /**
        Sets the address of the HigherPumpTokenMasterCopy
     */
    function setHigherPumpTokenMasterCopy(address _HigherPumpTokenMasterCopy) external onlyOwner {
        HigherPumpTokenMasterCopy = _HigherPumpTokenMasterCopy;
    }

    /**
        Sets Paused
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    /**
        Sets the address of the HigherPumpBondingCurveMasterCopy
     */
    function setHigherPumpBondingCurveMasterCopy(address _HigherPumpBondingCurveMasterCopy) external onlyOwner {
        HigherPumpBondingCurveMasterCopy = _HigherPumpBondingCurveMasterCopy;
    }

    /**
        Sets the address of the HigherPumpGenerator
     */
    function setHigherPumpGenerator(address _HigherPumpGenerator) external onlyOwner {
        HigherPumpGenerator = _HigherPumpGenerator;
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
        Sets the Higher volume tracker
     */
    function setHigherVolumeTracker(address _HigherVolumeTracker) external onlyOwner {
        HigherVolumeTracker = _HigherVolumeTracker;
    }

    /**
        Sets the address of the contract that can register volume
     */
    function setCanRegisterVolume(address _canRegisterVolume) external onlyOwner {
        canRegisterVolume[_canRegisterVolume] = true;
    }

    /**
        Sets the address of the contract that can register volume
     */
    function setProjectCreatorRewardsAddress(address token, address _projectCreatorRewardsAddress) external onlyOwner {
        projects[assetToProject[token]].creatorAddress = _projectCreatorRewardsAddress;
    }

    function addDevFee(address dev) external override payable {
        if (msg.value == 0) {
            return;
        }
        if (dev == address(0)) {
            TransferHelper.safeTransferETH(feeRecipient, msg.value);
            return;
        }
        unchecked {
            devFees[dev].pendingDevFees += msg.value;
        }
    }

    function claimDevFee(address dev) external {
        uint256 pendingDevFees = devFees[dev].pendingDevFees;
        require(pendingDevFees > 0, "No pending dev fees");
        devFees[dev].claimedDevFees += pendingDevFees;
        devFees[dev].pendingDevFees = 0;
        (bool s,) = payable(dev).call{value: pendingDevFees}("");
        require(s, "Failed to send dev fees");
    }

    function registerVolume(address token, address user, uint256 amount) external override {
        if (isCurveOrAdder(msg.sender) == false) {
            return;
        }
        if (amount == 0 || user == address(0) || HigherVolumeTracker == address(0)) {
            return;
        }

        // register volume
        IHigherVolumeTracker(HigherVolumeTracker).addVolume(user, token, amount);
    }

    function isCurveOrAdder(address addr) public view returns (bool) {
        return projects[assetToProject[bondingCurveToToken[msg.sender]]].bondingCurve == msg.sender || canRegisterVolume[msg.sender] || addr == liquidityAdder;
    }

    function bondProject() external override {

        // fetch project from bonding curve
        uint256 projectID = assetToProject[bondingCurveToToken[msg.sender]];
        if (projects[projectID].bondingCurve != msg.sender || projectID == 0) {
            return;
        }

        // add to bonded projects
        EnumerableSet.add(bondedProjects, projectID);

        // remove from pre-bonded projects
        EnumerableSet.remove(preBondedProjects, projectID);

        // emit Bonded event
        emit Bonded(bondingCurveToToken[msg.sender]);
    }

    function launchProject(
        string[] calldata metadata,
        bytes calldata tokenPayload,
        bytes calldata bondingCurvePayload,
        string calldata name,
        string calldata symbol
    ) external payable returns (uint256) {
        require(
            !paused,
            'Paused'
        );
        // ensure fees are taken
        require(
            msg.value >= launchFee,
            'Insufficient Fee'
        );

        // redefine args for stack
        string memory _name = name;
        string memory _symbol = symbol;
        bytes memory _tokenPayload = tokenPayload;
        bytes memory _bondingCurvePayload = bondingCurvePayload;
        string[] memory _metadata = metadata;

        // send fee to fee recipient
        TransferHelper.safeTransferETH(feeRecipient, launchFee);

        // generate token and bonding curve
        (address token, address bondingCurve) = IHigherGenerator(HigherPumpGenerator).generateProject(_name, _symbol, _tokenPayload, _bondingCurvePayload, liquidityAdder);

        // store project
        projects[projectNonce] = Project({
            asset: token,
            bondingCurve: bondingCurve,
            metadata: _metadata,
            name: _name,
            symbol: _symbol,
            dev: tx.origin,
            creatorAddress: tx.origin,
            launchTime: block.timestamp
        });

        // store asset to project mapping
        assetToProject[token] = projectNonce;

        // store bonding curve to token launch
        bondingCurveToToken[bondingCurve] = token;

        // add to list
        EnumerableSet.add(preBondedProjects, projectNonce);

        // add to dev list
        allDevProjects[tx.origin].push(projectNonce);

        // emit new event
        emit NewTokenCreated(tx.origin, token, bondingCurve, _name, _symbol);

        // increment nonce
        unchecked {
            ++projectNonce;
        }

        // if user supplied more value than launch fee, use it to buy tokens for them
        if (msg.value > launchFee) {
            IBondingCurve(bondingCurve).buyTokens{value: msg.value - launchFee}(msg.sender, 0);
        }

        return projectNonce - 1;
    }

    function getHigherPumpTokenMasterCopy() external view override returns (address) {
        return HigherPumpTokenMasterCopy;
    }

    function getLaunchTime(address token) external view returns (uint256) {
        return projects[assetToProject[token]].launchTime;
    }

    function getAllDevProjects(address dev) external view returns (uint256[] memory) {
        return allDevProjects[dev];
    }

    function getNumDevProjects(address dev) external view returns (uint256) {
        return allDevProjects[dev].length;
    }

    function getLatestDevProject(address dev) external view returns (uint256) {
        if (allDevProjects[dev].length == 0) {
            return 0;
        }
        return allDevProjects[dev][allDevProjects[dev].length - 1];
    }

    function getBondingCurveMasterCopy() external view override returns (address) {
        return HigherPumpBondingCurveMasterCopy;
    }

    function getHigherPumpGenerator() external view override returns (address) {
        return HigherPumpGenerator;
    }

    function isBonded(address token) external view override returns (bool) {
        return IBondingCurve(projects[assetToProject[token]].bondingCurve).isBonded();
    }

    function isBondedByID(uint256 projectID) external view returns (bool) {
        return IBondingCurve(projects[projectID].bondingCurve).isBonded();
    }

    function isHigherPumpToken(address token) external view override returns (bool) {
        return assetToProject[token] != 0 && projects[assetToProject[token]].asset == token;
    }

    function getBondingCurveForToken(address token) external view override returns (address) {
        return projects[assetToProject[token]].bondingCurve;
    }

    function getProjectMetadata(address token) external view returns (string[] memory) {
        return projects[assetToProject[token]].metadata;
    }

    function getProjectDev(address token) external view override returns (address) {
        return projects[assetToProject[token]].dev;
    }

    function getProjectCreatorRewardsAddress(address token) external view override returns (address) {
        return projects[assetToProject[token]].creatorAddress;
    }

    function getLiquidityLocker() external pure override returns (address) {
        return liquidityPermaLocker;
    }

    function getFeeRecipient() external view override returns (address) {
        return feeRecipient;
    }

    function owner() external view override returns (address) {
        return this.getOwner();
    }

    function getProjectInfoByToken(address token) public view returns (address, address, string[] memory, address) {
        Project memory project = projects[assetToProject[token]];
        return (project.asset, project.bondingCurve, project.metadata, project.dev);
    }

    function getProjectIDsByTokens(address[] calldata tokens) external view returns (uint256[] memory) {
        uint len = tokens.length;
        uint256[] memory projectIDs = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            projectIDs[i] = assetToProject[tokens[i]];
        }
        return projectIDs;
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

    function batchGetProjectAvancedInfo(uint256[] calldata projectIDs) public view returns (
        address[] memory assets, 
        address[] memory bondingCurves, 
        string[][] memory metadata, 
        address[] memory devs,
        string[] memory names,
        string[] memory symbols,
        uint256[] memory launchTimes,
        bool[] memory isBonded_
    ) {
        
        uint len = projectIDs.length;
        assets = new address[](len);
        bondingCurves = new address[](len);
        metadata = new string[][](len);
        devs = new address[](len);
        names = new string[](len);
        symbols = new string[](len);
        launchTimes = new uint256[](len);
        isBonded_ = new bool[](len);


        for (uint256 i = 0; i < len; i++) {
            Project memory project = projects[projectIDs[i]];
            assets[i] = project.asset;
            bondingCurves[i] = project.bondingCurve;
            metadata[i] = project.metadata;
            devs[i] = project.dev;
            names[i] = project.name;
            symbols[i] = project.symbol;
            launchTimes[i] = project.launchTime;
            isBonded_[i] = IBondingCurve(project.bondingCurve).isBonded();
        }

        return (assets, bondingCurves, metadata, devs, names, symbols, launchTimes, isBonded_);
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