//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IFeeRecipient {
    function takeBondFee(address token) external payable;
    function takeVolumeFee(address token) external payable;
    function takeFee(address pair) external payable;
}

interface IDatabase {
    function getProjectDev(address token) external view returns (address);
    function addDevFee(address dev) external payable;
}

interface IHigherPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
}

import "./lib/TransferHelper.sol";

contract FeeReceiver is IFeeRecipient {

    address public immutable database;
    address public immutable platformRecipient;
    address public immutable buyBurnRecipient;
    address public immutable stakingRecipient;

    uint256 public constant devCut = 50;
    uint256 public constant buyBurnCut = 50;
    uint256 public constant stakingCut = 25;
    uint256 public constant FEE_DENOMINATOR = 150;

    address public constant WETH = 0x6100E367285b01F48D07953803A2d8dCA5D19873;

    constructor(address _platformRecipient, address _buyBurnRecipient, address _stakingRecipient, address _database) {
        database = _database;
        platformRecipient = _platformRecipient;
        buyBurnRecipient = _buyBurnRecipient;
        stakingRecipient = _stakingRecipient;
    }

    function takeBondFee(address token) external payable override {
        splitFees(address(this).balance, IDatabase(database).getProjectDev(token));
    }

    function takeVolumeFee(address token) external payable override {
        splitFees(address(this).balance, IDatabase(database).getProjectDev(token));
    }
    
    function takeRouterFee(address pair, address user) external override payable returns (address token) {

        // get token0 and token1 from pair
        address token0 = IHigherPair(pair).token0();
        address token1 = IHigherPair(pair).token1();

        // find the one that is not WETH
        token = token0 == WETH ? token1 : token0;

        // get the dev from the database
        address dev = IDatabase(database).getProjectDev(token);

        // split fees    
        splitFees(address(this).balance, dev);
    }

    function splitFees(uint256 amount, address dev) internal {
        
        // split fees
        uint256 devFee = ( amount * devCut ) / FEE_DENOMINATOR;
        uint256 buyBurnFee = ( amount * buyBurnCut ) / FEE_DENOMINATOR;
        uint256 stakingFee = ( amount * stakingCut ) / FEE_DENOMINATOR;
        uint256 platformFee = amount - ( devFee + buyBurnFee + stakingFee );
        
        // send fees if able to
        if (devFee > 0) {
            IDatabase(database).addDevFee{value: devFee}(dev);
        }
        if (buyBurnFee > 0) {
            if (buyBurnRecipient == address(0)) {
                TransferHelper.safeTransferETH(platformRecipient, buyBurnFee);
            } else {
                TransferHelper.safeTransferETH(buyBurnRecipient, buyBurnFee);
            }
        }
        if (stakingFee > 0) {
            if (stakingRecipient == address(0)) {
                TransferHelper.safeTransferETH(platformRecipient, stakingFee);
            } else {
                TransferHelper.safeTransferETH(stakingRecipient, stakingFee);
            }
        }
        if (platformFee > 0) {
            TransferHelper.safeTransferETH(platformRecipient, platformFee);
        }
    }

    receive() external payable {
        TransferHelper.safeTransferETH(platformRecipient, address(this).balance);
    }

}