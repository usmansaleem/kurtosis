// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Contract2.sol";

contract Contract3 {
    Contract2 public contract2;
    uint256 public lastResult;
    event NestedCallMade(address to, uint256 result);

    constructor(address _contract2Address) {
        contract2 = Contract2(_contract2Address);
    }

    function nestedSetValue(uint256 newValue) public returns (uint256) {
        uint256 result = contract2.callSetValue(newValue);
        lastResult = result;
        emit NestedCallMade(address(contract2), result);
        return result;
    }

    function nestedGetValue() public view returns (uint256) {
        return contract2.callGetValue();
    }

    function nestedRevert() public {
        contract2.callRevert();
    }

    function deepRecursiveCall(uint256 depth, uint256 value) public returns (uint256) {
        return contract2.recursiveCall(depth, value);
    }

    function multipleCallsInOneTransaction(uint256 value1, uint256 value2) public returns (uint256) {
        contract2.callSetValue(value1);
        return contract2.callSetValue(value2);
    }

    function delegateCallToContract2(uint256 newValue) public returns (uint256) {
        (bool success, bytes memory data) = address(contract2).delegatecall(
            abi.encodeWithSignature("callSetValue(uint256)", newValue)
        );
        require(success, "Delegatecall failed");
        return abi.decode(data, (uint256));
    }

    function staticCallToContract2() public view returns (uint256) {
        (bool success, bytes memory data) = address(contract2).staticcall(
            abi.encodeWithSignature("callGetValue()")
        );
        require(success, "Staticcall failed");
        return abi.decode(data, (uint256));
    }
}