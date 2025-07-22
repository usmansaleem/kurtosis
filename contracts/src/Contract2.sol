// contracts/src/Contract2.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Contract1.sol";

contract Contract2 {
    Contract1 public contract1;

    constructor(address _contract1Address) {
        contract1 = Contract1(_contract1Address);
    }

    function callSetValue(uint256 newValue) public returns (uint256) {
        return contract1.setValue(newValue);
    }

    function callRevert() public {
        contract1.revertWithReason();
    }
}

