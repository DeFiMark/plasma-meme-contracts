//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IDatabase {
    function isBonded(address token) external view returns (bool);
    function isHigherPumpToken(address token) external view returns (bool);
    function getHigherPumpTokenMasterCopy() external view returns (address);
    function getBondingCurveMasterCopy() external view returns (address);
    function getBondingCurveForToken(address token) external view returns (address);
    function getLiquidityLocker() external view returns (address);
    function getFeeRecipient() external view returns (address);
    function bondProject() external;
    function registerVolume(address token, address user, uint256 amount) external;
    function getHigherPumpGenerator() external view returns (address);
    function owner() external view returns (address);
}

interface IBondingCurve {
    function getVersionNo() external view returns (uint32);
    function isBonded() external view returns (bool);
    function __init__(bytes calldata payload, address token, address liquidityAdder) external;
    function getToken() external view returns (address);
    function buyTokens(address recipient, uint256 minOut) external payable returns (uint256 tokensBought);
}

interface IHigherGenerator {
    function generateProject(bytes calldata tokenPayload, bytes calldata bondingCurvePayload, address liquidityAdder) external returns (address token, address bondingCurve);
}

interface IHigherVolumeTracker {
    function addVolume(address user, address token, uint256 volume) external;
}


/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```solidity
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableSet.
 * ====
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position is the index of the value in the `values` array plus 1.
        // Position 0 is used to mean a value is not in the set.
        mapping(bytes32 => uint256) _positions;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._positions[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We cache the value's position to prevent multiple reads from the same storage slot
        uint256 position = set._positions[value];

        if (position != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 valueIndex = position - 1;
            uint256 lastIndex = set._values.length - 1;

            if (valueIndex != lastIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the lastValue to the index where the value to delete is
                set._values[valueIndex] = lastValue;
                // Update the tracked position of the lastValue (that was just moved)
                set._positions[lastValue] = position;
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the tracked position for the deleted slot
            delete set._positions[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._positions[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        bytes32[] memory store = _values(set._inner);
        bytes32[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}


/**
 * @title Owner
 * @dev Set & change owner
 */
contract Ownable {

    address private owner;
    
    // event for EVM logging
    event OwnerSet(address indexed oldOwner, address indexed newOwner);
    
    // modifier to check if caller is owner
    modifier onlyOwner() {
        // If the first argument of 'require' evaluates to 'false', execution terminates and all
        // changes to the state and to Ether balances are reverted.
        // This used to consume all gas in old EVM versions, but not anymore.
        // It is often a good idea to use 'require' to check if functions are called correctly.
        // As a second argument, you can also provide an explanation about what went wrong.
        require(msg.sender == owner, "Caller is not owner");
        _;
    }
    
    /**
     * @dev Set contract deployer as owner
     */
    constructor() {
        owner = msg.sender; // 'msg.sender' is sender of current call, contract deployer for a constructor
        emit OwnerSet(address(0), owner);
    }

    /**
     * @dev Change owner
     * @param newOwner address of new owner
     */
    function changeOwner(address newOwner) public onlyOwner {
        emit OwnerSet(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @dev Return owner address 
     * @return address of owner
     */
    function getOwner() external view returns (address) {
        return owner;
    }
}


// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeApprove: approve failed'
        );
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeTransfer: transfer failed'
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::transferFrom: transferFrom failed'
        );
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');
    }
}

contract HigherDatabase is IDatabase, Ownable {

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

    // Router
    address public router;

    // Higher Volume Tracker
    address public HigherVolumeTracker;

    // List of all bonded projects
    EnumerableSet.UintSet private bondedProjects;

    // Lits of all pre-bonded projects
    EnumerableSet.UintSet private preBondedProjects;

    // Pauses all new launches
    bool public paused;

    // Event emitted when project is created
    event NewTokenCreated(address indexed dev, address token, address bondingCurve, uint nonce, bytes projectData);
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
        Sets the router
     */
    function setRouter(address _router) external onlyOwner {
        router = _router;
        canRegisterVolume[_router] = true;
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

    function addDevFee(address dev) external payable {
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
        bytes calldata bondingCurvePayload
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

        // send fee to fee recipient
        TransferHelper.safeTransferETH(feeRecipient, launchFee);

        // generate token and bonding curve
        (address token, address bondingCurve) = IHigherGenerator(HigherPumpGenerator).generateProject(tokenPayload, bondingCurvePayload, liquidityAdder);

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

        // add to dev list
        allDevProjects[tx.origin].push(projectNonce);

        // emit new event
        emit NewTokenCreated(tx.origin, token, bondingCurve, projectNonce, abi.encode(metadata, tokenPayload, bondingCurvePayload));

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

    function getProjectDev(address token) external view returns (address) {
        return projects[assetToProject[token]].dev;
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