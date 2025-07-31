// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract RevertContract {
    uint256 public value;

    // Will revert if _value is greater than 100
    function setValue(uint256 _value) public returns (uint256) {
        require(_value <= 100, "Value must be less than or equal to 100");
        value = _value;
        return value;
    }

    // Will always revert with a custom error message
    // Add a uint256 return type to match the try-catch
    function alwaysRevert() public pure returns (uint256) {
        revert("This function always reverts");
        return 0; // This line never executes due to the revert
    }

    // Will revert in a nested call
    function nestedRevert() public returns (uint256) {
        return this.alwaysRevert();
    }
}