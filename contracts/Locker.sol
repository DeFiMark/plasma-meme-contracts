//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./interfaces/IERC20.sol";
import "./lib/TransferHelper.sol";
import "./lib/ReentrancyGuard.sol";
import "./lib/EnumerableSet.sol";

contract Locker is ReentrancyGuard {

    // Lock struct
    struct Lock {
        address token;
        uint256 amount;
        uint256 unlockTime;
        address recipient;
    }

    // maps a lock id to a lock
    mapping ( uint256 => Lock ) public locks;

    // Lock ID
    uint256 public lockNonce;

    // maps a user to a list of lock ids
    mapping ( address => EnumerableSet.UintSet ) private userLocks;

    // maps a token to a list of lock ids
    mapping ( address => EnumerableSet.UintSet ) private tokenLocks;

    // List of current locks
    EnumerableSet.UintSet private currentLocks;

    event LockCreated(address indexed token, address indexed user, uint256 lockId, uint256 amount, uint256 unlockTime);
    event Unlocked(address indexed token, address indexed user, uint256 lockId, uint256 amount);
    event LockExtended(address indexed token, address indexed user, uint256 lockId, uint256 newUnlockTime);

    function lock(address token, uint256 amount, uint256 duration) external nonReentrant {
        require(token != address(0), "Locker: No token");
        require(amount > 0, "Locker: No amount");
        require(duration > 0, "Locker: No duration");
        
        // transfer in tokens
        uint256 received = _transferIn(token, amount);

        // create lock
        locks[lockNonce] = Lock({
            token: token,
            amount: received,
            unlockTime: block.timestamp + duration,
            recipient: msg.sender
        });

        // add lock id to user locks
        EnumerableSet.add(userLocks[msg.sender], lockNonce);

        // add lock id to token locks
        EnumerableSet.add(tokenLocks[token], lockNonce);

        // add lock id to current locks
        EnumerableSet.add(currentLocks, lockNonce);

        // emit lock created
        emit LockCreated(token, msg.sender, lockNonce, received, block.timestamp + duration);

        // increment lock id
        unchecked {
            ++lockNonce;
        }
    }


    function unlock(uint256 lockId) external nonReentrant {
        require(locks[lockId].recipient == msg.sender, "Locker: Not the recipient");
        require(locks[lockId].amount > 0, "Locker: No amount");
        require(locks[lockId].token != address(0), "Locker: No token");
        require(locks[lockId].unlockTime > 0, "Locker: No unlock time");
        require(timeUntilUnlock(lockId) == 0, "Locker: Not unlocked");
        require(EnumerableSet.contains(currentLocks, lockId), "Locker: Not a current lock");

        // remove lock id from user locks
        EnumerableSet.remove(userLocks[msg.sender], lockId);

        // remove lock id from token locks
        EnumerableSet.remove(tokenLocks[locks[lockId].token], lockId);

        // remove lock id from current locks
        EnumerableSet.remove(currentLocks, lockId);

        // fetch lock amount
        uint256 amount = locks[lockId].amount;
        address token = locks[lockId].token;

        // delete lock info
        delete locks[lockId];

        // transfer out tokens
        TransferHelper.safeTransfer(token, msg.sender, amount);

        // emit unlocked
        emit Unlocked(token, msg.sender, lockId, amount);
    }

    function extendLock(uint256 lockId, uint256 duration) external nonReentrant {
        require(locks[lockId].recipient == msg.sender, "Locker: Not the recipient");
        require(locks[lockId].amount > 0, "Locker: No amount");
        require(locks[lockId].token != address(0), "Locker: No token");
        require(locks[lockId].unlockTime > 0, "Locker: No unlock time");
        require(EnumerableSet.contains(currentLocks, lockId), "Locker: Not a current lock");

        // update unlock time based on unlock time of the initial lock
        uint256 unlockTime = locks[lockId].unlockTime;

        // increase unlock time by duration, if the lock is already unlocked, set the new unlock time to the current time + duration
        uint256 newUnlockTime = unlockTime < block.timestamp ? block.timestamp + duration : unlockTime + duration;

        // update lock info
        locks[lockId].unlockTime = newUnlockTime;

        // emit lock extended
        emit LockExtended(locks[lockId].token, msg.sender, lockId, newUnlockTime);
    }

    function _transferIn(address token, uint256 amount) internal returns (uint256) {
        require(IERC20(token).balanceOf(msg.sender) >= amount, "Locker: Insufficient balance");
        require(IERC20(token).allowance(msg.sender, address(this)) >= amount, "Locker: Insufficient allowance");
        uint before = IERC20(token).balanceOf(address(this));
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amount);
        uint After = IERC20(token).balanceOf(address(this));
        require(After > before, "Locker: Failed to transfer in tokens");
        return After - before;
    }

    function timeUntilUnlock(uint256 lockId) public view returns (uint256) {
        return block.timestamp >= locks[lockId].unlockTime ? 0 : locks[lockId].unlockTime - block.timestamp;
    }

    function getAllUserLocks(address user) external view returns (uint256[] memory) {
        return EnumerableSet.values(userLocks[user]);
    }

    function getAllTokenLocks(address token) external view returns (uint256[] memory) {
        return EnumerableSet.values(tokenLocks[token]);
    }

    function getAllCurrentLocks() external view returns (uint256[] memory) {
        return EnumerableSet.values(currentLocks);
    }

    function getLock(uint256 lockId) external view returns (Lock memory) {
        return locks[lockId];
    }

    function getUserLockAtIndex(address user, uint256 index) external view returns (uint256) {
        return EnumerableSet.at(userLocks[user], index);
    }

    function getTokenLockAtIndex(address token, uint256 index) external view returns (uint256) {
        return EnumerableSet.at(tokenLocks[token], index);
    }

    function getCurrentLockAtIndex(uint256 index) external view returns (uint256) {
        return EnumerableSet.at(currentLocks, index);
    }

    function getNumUserLocks(address user) external view returns (uint256) {
        return EnumerableSet.length(userLocks[user]);
    }

    function getNumTokenLocks(address token) external view returns (uint256) {
        return EnumerableSet.length(tokenLocks[token]);
    }

    function getNumCurrentLocks() external view returns (uint256) {
        return EnumerableSet.length(currentLocks);
    }

    function paginateCurrentLocks(uint256 startIndex, uint256 endIndex) external view returns (uint256[] memory) {
        if (endIndex > EnumerableSet.length(currentLocks)) {
            endIndex = EnumerableSet.length(currentLocks);
        }
        uint256[] memory _currentLocks = new uint256[](endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex;) {
            _currentLocks[i - startIndex] = EnumerableSet.at(currentLocks, i);
            unchecked { ++i; }
        }
        return _currentLocks;
    }

    function paginateTokenLocks(address token, uint256 startIndex, uint256 endIndex) external view returns (uint256[] memory) {
        if (endIndex > EnumerableSet.length(tokenLocks[token])) {
            endIndex = EnumerableSet.length(tokenLocks[token]);
        }
        uint256[] memory _tokenLocks = new uint256[](endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex;) {
            _tokenLocks[i - startIndex] = EnumerableSet.at(tokenLocks[token], i);
            unchecked { ++i; }
        }
        return _tokenLocks;
    }
    
    function paginateUserLocks(address user, uint256 startIndex, uint256 endIndex) external view returns (uint256[] memory) {
        if (endIndex > EnumerableSet.length(userLocks[user])) {
            endIndex = EnumerableSet.length(userLocks[user]);
        }
        uint256[] memory _userLocks = new uint256[](endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex;) {
            _userLocks[i - startIndex] = EnumerableSet.at(userLocks[user], i);
            unchecked { ++i; }
        }
        return _userLocks;
    }

    function batchLockInfo(uint256[] calldata lockIds) external view returns (address[] memory, uint256[] memory, uint256[] memory, address[] memory) {
        uint256 length = lockIds.length;
        address[] memory tokens = new address[](length);
        uint256[] memory amounts = new uint256[](length);
        uint256[] memory timesUntilUnlock = new uint256[](length);
        address[] memory recipients = new address[](length);
        for (uint256 i = 0; i < length;) {
            tokens[i] = locks[lockIds[i]].token;
            amounts[i] = locks[lockIds[i]].amount;
            timesUntilUnlock[i] = timeUntilUnlock(lockIds[i]);
            recipients[i] = locks[lockIds[i]].recipient;
            unchecked { ++i; }
        }
        return (tokens, amounts, timesUntilUnlock, recipients);
    }

}