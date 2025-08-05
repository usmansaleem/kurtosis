// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RevertTestContract} from "./RevertTestContract.sol";

contract RevertHelper {
    event RevertCaught(string reason);

    // Call a function that will revert
    function callRevertingFunction(address testContract) public returns (bool) {
        RevertTestContract test = RevertTestContract(testContract);

        try test.alwaysRevert() returns (uint256) {
            return true; // Will never happen
        } catch Error(string memory reason) {
            emit RevertCaught(reason);
            return false;
        } catch (bytes memory) {
            emit RevertCaught("Unknown error");
            return false;
        }
    }

    // Call a function that will revert with a value that's too high
    function callSetValue(address testContract, uint256 value) public returns (bool) {
        RevertTestContract test = RevertTestContract(testContract);

        try test.setValue(value) returns (uint256) {
            return true; // Will succeed if value <= 100
        } catch Error(string memory reason) {
            emit RevertCaught(reason);
            return false;
        } catch (bytes memory) {
            emit RevertCaught("Unknown error");
            return false;
        }
    }

    // Call a function that will cause nested revert
    function callNestedRevert(address testContract) public returns (bool) {
        RevertTestContract test = RevertTestContract(testContract);

        try test.nestedRevert() {
            return true; // Will never happen
        } catch Error(string memory reason) {
            emit RevertCaught(reason);
            return false;
        } catch (bytes memory) {
            emit RevertCaught("Unknown error");
            return false;
        }
    }

    // Direct call without try/catch - this transaction will revert
    // Useful for testing revert handling directly
    function directRevertingCall(address testContract) public {
        RevertTestContract test = RevertTestContract(testContract);
        test.alwaysRevert();
    }
}