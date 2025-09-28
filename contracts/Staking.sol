//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

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

interface IERC20 {

    function totalSupply() external view returns (uint256);
    
    function symbol() external view returns(string memory);
    
    function name() external view returns(string memory);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);
    
    /**
     * @dev Returns the number of decimal places
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    constructor () {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract PlasmaStaking is Ownable, ReentrancyGuard {

    // name and symbol for tokenized contract
    string private constant _name = "Staked HIGHER";
    string private constant _symbol = "sHIGHER";
    uint8 private constant _decimals = 18;

    // lock time in seconds
    uint256 public lockTime = 7 days;

    // Staking Token
    address public immutable token;

    // User Info
    struct UserInfo {
        uint256 amount;
        uint256 unlockTime;
        uint256 totalExcluded;
    }
    // Address => UserInfo
    mapping ( address => UserInfo ) public userInfo;

    // Tracks Dividends
    uint256 public totalRewards;
    uint256 private totalShares;
    uint256 private dividendsPerShare;
    uint256 private constant precision = 10**18;

    // Events
    event SetLockTime(uint LockTime);
    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor(address token_){
        require(
            token_ != address(0),
            'Zero Address'
        );
        token = token_;
        emit Transfer(address(0), msg.sender, 0);
    }

    /** Returns the total number of tokens in existence */
    function totalSupply() external view returns (uint256) { 
        return totalShares; 
    }

    /** Returns the number of tokens owned by `account` */
    function balanceOf(address account) public view returns (uint256) { 
        return userInfo[account].amount;
    }

    /** Token Name */
    function name() public pure returns (string memory) {
        return _name;
    }

    /** Token Ticker Symbol */
    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    /** Tokens decimals */
    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function setLockTime(uint256 newLockTime) external onlyOwner {
        require(
            newLockTime < 31 days,
            'Lock Time Too Long'
        );
        lockTime = newLockTime;
        emit SetLockTime(newLockTime);
    }

    function withdrawForeignToken(address token_) external onlyOwner {
        require(
            token != token_,
            'Cannot Withdraw Staked Token'
        );
        require(
            IERC20(token_).transfer(
                msg.sender,
                IERC20(token_).balanceOf(address(this))
            ),
            'Failure On Token Withdraw'
        );
    }

    function claimRewards() external nonReentrant {
        _claimReward(msg.sender);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(
            amount <= userInfo[msg.sender].amount,
            'Insufficient Amount'
        );
        require(
            amount > 0,
            'Zero Amount'
        );
        require(
            timeUntilUnlock(msg.sender) == 0,
            'Not Unlocked'
        );

        // claim rewards if any
        if (userInfo[msg.sender].amount > 0) {
            _claimReward(msg.sender);
        }

        // decrease shares and amount
        unchecked {
            totalShares -= amount;
            userInfo[msg.sender].amount -= amount;
        }
        
        // update total excluded
        userInfo[msg.sender].totalExcluded = getCumulativeDividends(userInfo[msg.sender].amount);

        // emit transfer
        emit Transfer(msg.sender, address(0), amount);

        // transfer to sender
        TransferHelper.safeTransfer(token, msg.sender, amount);
    }

    function stake(uint256 amount) external nonReentrant {
        if (userInfo[msg.sender].amount > 0) {
            _claimReward(msg.sender);
        }

        // transfer in tokens
        uint received = _transferIn(token, amount);
        
        // update data
        unchecked {
            totalShares += received;
            userInfo[msg.sender].amount += received;
            userInfo[msg.sender].unlockTime = block.timestamp + lockTime;
        }
        userInfo[msg.sender].totalExcluded = getCumulativeDividends(userInfo[msg.sender].amount);

        emit Transfer(address(0), msg.sender, amount);
    }

    function depositRewards() external payable nonReentrant {
        if (totalShares == 0) {
            return;
        }
        
        // update state
        unchecked {
            dividendsPerShare += ( msg.value * precision ) / totalShares;
            totalRewards += msg.value;
        }
    }


    function _claimReward(address user) internal {

        // exit if zero value locked
        if (userInfo[user].amount == 0) {
            return;
        }

        // fetch pending rewards
        uint256 amount = pendingRewards(user);
        
        // exit if zero rewards
        if (amount == 0) {
            return;
        }

        // update total excluded
        userInfo[user].totalExcluded = getCumulativeDividends(userInfo[user].amount);

        // transfer reward to user
        TransferHelper.safeTransferETH(user, amount);
    }

    function _transferIn(address _token, uint256 amount) internal returns (uint256) {
        uint before = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transferFrom(msg.sender, address(this), amount);
        uint After = IERC20(_token).balanceOf(address(this));
        require(
            After > before,
            'Error On TransferIn'
        );
        return After - before;
    }

    function timeUntilUnlock(address user) public view returns (uint256) {
        return userInfo[user].unlockTime < block.timestamp ? 0 : userInfo[user].unlockTime - block.timestamp;
    }

    function pendingRewards(address shareholder) public view returns (uint256) {
        if(userInfo[shareholder].amount == 0){ return 0; }

        uint256 totalDividends = getCumulativeDividends(userInfo[shareholder].amount);
        uint256 tExcluded = userInfo[shareholder].totalExcluded;

        if(totalDividends <= tExcluded){ return 0; }

        return totalDividends <= tExcluded ? 0 : totalDividends - tExcluded;
    }

    function getCumulativeDividends(uint256 share) internal view returns (uint256) {
        return ( share * dividendsPerShare ) / precision;
    }

    receive() external payable {
        if (totalShares == 0) {
            return;
        }
        
        // update state
        unchecked {
            dividendsPerShare += ( msg.value * precision ) / totalShares;
            totalRewards += msg.value;
        }
    }

}