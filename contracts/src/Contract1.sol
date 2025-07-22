// contracts/src/Contract1.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Contract1 {
       uint256 public value;

       function setValue(uint256 newValue) public returns (uint256) {
           value = newValue;
           return newValue;
       }

       function revertWithReason() public pure {
           revert("Reverted intentionally");
       }
}