//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./interfaces/IDatabase.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ILiquidityAdder.sol";
import "./interfaces/IFeeRecipient.sol";
import "./lib/Ownable.sol";

/**
    Receives Tokens and Native Assets from the Bonding Curve and adds them to the desired DEX

    NOTE: ADD FAIL SAFE IN CASE OF UNFORSEEN EVENT -- WORST CASE IS FUNDS ARE LOCKED!!!
 */
contract LiquidityAdder is Ownable, ILiquidityAdder {

    // Lunar Database
    address private immutable database;

    // Fee on bonding
    uint256 public bondFee = 200; // 20%

    // DEX Info
    address public dex = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1;
    address public factory = 0x6725F303b657a9451d8BA641348b6761A6CC7a17;
    address public WETH = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    bytes32 public INIT_CODE_PAIR_HASH = 0xd0d4c4cd0848c93cb4fd1f498d7013ee6bfb25783ea21593d5834f5d250ece66;

    // Whether or not dust is enforced
    bool public enforceDust;

    // Emitted when a token successfully bonds
    event Bonded(address token);

    constructor(address _database) {
        database = _database;
    }

    modifier onlyLunarPumpTokens(address token) {
        require(IDatabase(database).isLunarPumpToken(token), "LiquidityAdder: Token is not a LunarPump Token");
        _;
    }

    function withdrawETH() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "LiquidityAdder: Failed to withdraw ETH");
    }

    function withdrawToken(address token) external onlyOwner {
        IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    function setBondFee(uint256 _bondFee) external onlyOwner {
        bondFee = _bondFee;
    }

    function setDEX(address _dex) external onlyOwner {
        dex = _dex;
    }

    function setFactory(address _factory) external onlyOwner {
        factory = _factory;
    }

    function setWETH(address _WETH) external onlyOwner {
        WETH = _WETH;
    }

    function setEnforceDust(bool _enforceDust) external onlyOwner {
        enforceDust = _enforceDust;
    }
    
    function setInitCodePairHash(bytes32 _INIT_CODE_PAIR_HASH) external onlyOwner {
        INIT_CODE_PAIR_HASH = _INIT_CODE_PAIR_HASH;
    }

    function bond(address token) external payable override onlyLunarPumpTokens(token) {

        // ensure request comes from the bonding curve
        require(
            msg.sender == IDatabase(database).getBondingCurveForToken(token),
            "LiquidityAdder: Unauthorized"
        );
        
        // take fee
        uint256 liquidityAmount = _takeFee(token, msg.value);
        uint256 tokenAmount = IERC20(token).balanceOf(address(this));

        // determine if LP has been dusted prior to liquidity add, send liquidity to dex and call sync if dusted
        if (checkDusted(token) && enforceDust) {
            // add liquidity at equal ratio, call sync
            address pair = pairFor(token, WETH);
            uint256 wethAmountInLP = IERC20(WETH).balanceOf(pair);
            uint256 tokenAmountInLP = IERC20(token).balanceOf(pair);

            if (wethAmountInLP > 0 && isContract(pair)) {
                // ensure the ratio will match the desired ratio
                // ratio = tokenAmount * 1e18 / wethAmount
                // tokenAmount = (ratio * wethAmount) / 1e18
                uint256 desiredRatio = ( tokenAmount * 1e18 ) / liquidityAmount;
                uint256 desiredTokenAmount = ( ( desiredRatio * wethAmountInLP ) / 1e18 ) - tokenAmountInLP;

                // send desiredTokenAmount to dex and sync the LP
                IERC20(token).transfer(pair, desiredTokenAmount);

                // sync the LP
                IPair(pair).sync();

                // reduce from tokenAmount
                tokenAmount -= desiredTokenAmount;
            }
        }

        // add liquidity to dex
        IERC20(token).approve(dex, tokenAmount);
        IUniswapV2Router02(dex).addLiquidityETH{value: liquidityAmount}(
            token,
            tokenAmount,
            ( tokenAmount * 9 ) / 10,
            ( liquidityAmount * 9 ) / 10,
            IDatabase(database).getLiquidityLocker(),
            block.timestamp + 100
        );

        // emit Bonded event
        emit Bonded(token);
    }

    function _takeFee(address token, uint256 amount) internal returns (uint256 remainingForLiquidity) {

        // split fee
        uint256 fee = ( amount * bondFee ) / 1000;

        // send fee
        IFeeRecipient(IDatabase(database).getFeeRecipient()).takeBondFee{value: fee}(token);

        // return amount minus fee
        return amount - fee;
    }

    function checkDusted(address token) public view returns (bool) {
        // predict the LP token address for token
        address pair = pairFor(token, WETH);
        return IERC20(WETH).balanceOf(pair) > 0;
    }

    function getFeeRecipient() external view override returns (address) {
        return IDatabase(database).getFeeRecipient();
    }

    function getDatabase() external view override returns (address) {
        return database;
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address tokenA, address tokenB) internal view returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                INIT_CODE_PAIR_HASH
            )))));
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'DEXLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'DEXLibrary: ZERO_ADDRESS');
    }

    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }

    receive() external payable {}
}