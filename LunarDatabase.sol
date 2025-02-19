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
    }

    // Mapping of project nonce to project
    mapping (uint256 => Project) public projects;

    // Mapping of asset to project nonce
    mapping ( address => uint256 ) public assetToProject;

    // Master copy of the LunarPumpToken
    address internal lunarPumpTokenMasterCopy;

    // Master copy of the LunarPumpBondingCurve
    address internal lunarPumpBondingCurveMasterCopy;

    // LunarPumpGenerator
    address internal lunarPumpGenerator;

    // Launch fee
    uint256 public launchFee;

    // Fee recipient
    address public feeRecipient;

    // Project nonce
    uint256 public projectNonce;

    // Liquidity adder contract
    address public liquidityAdder;

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
            metadata: metadata
        });

        // store asset to project mapping
        assetToProject[token] = projectNonce;

        // increment nonce
        unchecked {
            ++projectNonce;
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

}