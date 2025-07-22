// contracts/src/Contract3.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Contract2.sol";

contract Contract3 {
    Contract2 public contract2;

    constructor(address _contract2Address) {
        contract2 = Contract2(_contract2Address);
    }

    function nestedSetValue(uint256 newValue) public view returns (uint256) {
        return contract2.callSetValue(newValue);
    }

    function nestedRevert() public view {
        contract2.callRevert();
    }
}
