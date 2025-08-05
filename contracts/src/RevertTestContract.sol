// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract RevertTestContract {
    uint256 public value;

        // Simple function to set a value - will revert if value > 100
        function setValue(uint256 _value) public returns (uint256) {
            require(_value <= 100, "Value too high");
            value = _value;
            return value;
        }

        // Function that always reverts with a custom message
        function alwaysRevert() public pure returns (uint256) {
            revert("This function always reverts");
            return 0; // Never reached
        }

        // Function with nested revert - calls alwaysRevert internally
        function nestedRevert() public {
            this.alwaysRevert();
        }

        // Function that reverts with custom error
        error CustomError(address sender, uint256 value);
        function revertWithCustomError(uint256 _value) public {
            revert CustomError(msg.sender, _value);
        }

        // Function that causes an out-of-gas error
        function causeOutOfGas() public {
            uint256[] memory array;
            while(true) {
                array = new uint256[](10000); // Will eventually run out of gas
            }
        }
}