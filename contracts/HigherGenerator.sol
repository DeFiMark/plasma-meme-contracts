//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
    Responsible for generating all contracts associated with a new project
    - Token Contract
    - Bonding Curve Contract

    Also adds these addresses and relevant information to the database
 */

import "./lib/Ownable.sol";
import "./interfaces/IBondingCurve.sol";
import "./interfaces/IHigherPumpToken.sol";
import "./interfaces/IHigherGenerator.sol";
import "./interfaces/IDatabase.sol";

contract HigherGenerator is IHigherGenerator {

    IDatabase public immutable database;

    constructor(address _database) {
        database = IDatabase(_database);
    }

    /**
        Generates a token and bonding curve, initializes both and returns their addresses
     */
    function generateProject(string calldata name, string calldata symbol, bytes calldata tokenPayload, bytes calldata bondingCurvePayload, address liquidityAdder) external override returns (address token, address bondingCurve) {
        token = generateToken();
        bondingCurve = generateBondingCurve();

        IHigherPumpToken(token).__init__(tokenPayload, name, symbol, bondingCurve);
        IBondingCurve(bondingCurve).__init__(bondingCurvePayload, token, liquidityAdder);

        return (token, bondingCurve);
    }

    /**
        @dev Deploys and returns the address of a clone of the higherPumpTokenMasterCopy
        Created by DeFi Mark To Allow Clone Contract To Easily Create Clones Of Itself
        Without redundancy
     */
    function generateToken() internal returns(address) {
        return _clone(database.getHigherPumpTokenMasterCopy());
    }

    /**
        @dev Deploys and returns the address of a clone of the higherPumpBondingCurveMasterCopy
        Created by DeFi Mark To Allow Clone Contract To Easily Create Clones Of Itself
        Without redundancy
     */
    function generateBondingCurve() internal returns(address) {
        return _clone(database.getBondingCurveMasterCopy());
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function _clone(address implementation) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create(0, ptr, 0x37)
        }
        require(instance != address(0), "ERC1167: create failed");
    }
}