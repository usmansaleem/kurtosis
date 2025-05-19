// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Contract1 {
    uint256 public value;
    event ValueSet(uint256 newValue, address caller);

    function setValue(uint256 newValue) public returns (uint256) {
        value = newValue;
        emit ValueSet(newValue, msg.sender);
        return value;
    }

    function getValue() public view returns (uint256) {
        return value;
    }

    function revertWithReason() public pure {
        revert("Contract1: Intentional revert");
    }
}