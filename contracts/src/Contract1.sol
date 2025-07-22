// contracts/src/Contract1.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Contract1 {
    function setValue(uint256 newValue) public pure returns (uint256) {
        return newValue;
    }

    function revertWithReason() public pure {
        revert("Reverted intentionally");
    }
}