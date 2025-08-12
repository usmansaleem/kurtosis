// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract DelegateProxy {
    address public impl;
    constructor(address _impl){ impl = _impl; }

    function dset(uint256 v) external {
        (bool ok, ) = impl.delegatecall(
            abi.encodeWithSignature("set(uint256)", v)
        );
        require(ok, "delegatecall failed");
    }
}