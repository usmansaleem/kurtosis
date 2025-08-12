// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract DelegateImpl {
    uint256 public x; // lives in proxy's storage during delegatecall
    function set(uint256 v) external { x = v; }
}