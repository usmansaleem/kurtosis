// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Counter.sol";

contract CounterCaller {
    Counter public counter;

    // Constructor accepts the address of the already deployed Counter contract
    constructor(address _counterAddress) {
        counter = Counter(_counterAddress);
    }

    // Function to call Counter's increment function
    function incrementCounter() public {
        counter.increment();
    }

    // Function to call Counter's setNumber function
    function setCounterNumber(uint256 newNumber) public {
        counter.setNumber(newNumber);
    }

    // Function to read the current number from Counter
    function getCounterNumber() public view returns (uint256) {
        return counter.number();
    }
}