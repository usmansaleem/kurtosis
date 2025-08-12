// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract PrecompileCaller {
    // Calls identity precompile (0x04) with arbitrary data and returns the echo
    function callIdentity(bytes calldata data) external returns (bytes memory out) {
        (bool ok, bytes memory ret) = address(0x04).staticcall(data);
        require(ok, "identity failed");
        return ret;
    }
}
