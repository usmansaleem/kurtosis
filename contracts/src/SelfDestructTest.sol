// contracts/src/SelfDestructTest.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract SelfDestructTest {
    address public owner;

    constructor() payable {
        owner = msg.sender;
    }

    // Receive function to accept ETH
    receive() external payable {}

    // Self-destruct and send remaining balance to beneficiary
    function destroy(address payable beneficiary) external {
        require(msg.sender == owner, "Only owner can destroy");
        selfdestruct(beneficiary);
    }

    // Helper to check balance
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}