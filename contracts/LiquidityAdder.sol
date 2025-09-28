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
 */
contract LiquidityAdder is Ownable, ILiquidityAdder {

    // Higher Database
    address private immutable database;

    // Fee on bonding
    uint256 public bondFee = 200; // 20%

    // token slippage
    uint256 public tokenSlippage = 50;

    // DEX Info
    address public dex;
    address public factory;
    address public constant WETH = 0x6100E367285b01F48D07953803A2d8dCA5D19873;
    bytes32 public INIT_CODE_PAIR_HASH;

    // Whether or not dust is enforced
    bool public enforceDust;

    constructor(address _database, address dex_, address factory_, bytes32 INIT_CODE_PAIR_HASH_) {
        database = _database;
        dex = dex_;
        factory = factory_;
        INIT_CODE_PAIR_HASH = INIT_CODE_PAIR_HASH_;
    }

    modifier onlyHigherPumpTokens(address token) {
        require(IDatabase(database).isHigherPumpToken(token), "LiquidityAdder: Token is not a HigherPump Token");
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

    function setTokenSlippage(uint256 newSlippage) external onlyOwner {
        tokenSlippage = newSlippage;
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

    function bond(address token) external payable override onlyHigherPumpTokens(token) {

        // ensure request comes from the bonding curve
        require(
            msg.sender == IDatabase(database).getBondingCurveForToken(token),
            "LiquidityAdder: Unauthorized"
        );
        
        // take fee
        uint256 liquidityAmount = _takeFee(token, msg.value);
        uint256 tokenAmount = IERC20(token).balanceOf(address(this));

        // add liquidity to dex
        IERC20(token).approve(dex, tokenAmount);
        IUniswapV2Router02(dex).addLiquidityETH{value: liquidityAmount}(
            token,
            tokenAmount,
            ( tokenAmount * tokenSlippage ) / 100,
            ( liquidityAmount * tokenSlippage ) / 100,
            IDatabase(database).getLiquidityLocker(),
            block.timestamp + 100
        );
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