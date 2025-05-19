// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Contract1.sol";

contract Contract2 {
    Contract1 public contract1;
    uint256 public lastResult;
    event CallMade(address to, uint256 result);

    constructor(address _contract1Address) {
        contract1 = Contract1(_contract1Address);
    }

    function callSetValue(uint256 newValue) public returns (uint256) {
        uint256 result = contract1.setValue(newValue);
        lastResult = result;
        emit CallMade(address(contract1), result);
        return result;
    }

    function callGetValue() public view returns (uint256) {
        return contract1.getValue();
    }

    function callRevert() public {
        contract1.revertWithReason();
    }

    function recursiveCall(uint256 depth, uint256 value) public returns (uint256) {
        if (depth == 0) {
            return contract1.setValue(value);
        }
        return this.recursiveCall(depth - 1, value);
    }
}