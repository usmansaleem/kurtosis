// contracts/src/FailedCallsTest.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract FailedCallsTest {
    // Events to track what happened
    event CallAttempted(address target, uint256 value);
    event CallSucceeded(address target, uint256 value);

    // Test insufficient balance for value transfer
    function testInsufficientBalance(address target) external {
        emit CallAttempted(target, 1 ether);

        // This contract has 0 balance, so this should fail with INSUFFICIENT_BALANCE
        (bool success, ) = target.call{value: 1 ether}("");

        if (success) {
            emit CallSucceeded(target, 1 ether);
        }
        // The call should fail silently (no revert)
    }

    // Test call with some balance
    function testSufficientBalance(address target) external payable {
        require(msg.value >= 1 ether, "Need 1 ether");
        emit CallAttempted(target, 1 ether);

        (bool success, ) = target.call{value: 1 ether}("");

        if (success) {
            emit CallSucceeded(target, 1 ether);
        }
    }
}