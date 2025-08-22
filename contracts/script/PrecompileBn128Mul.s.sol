// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PrecompileCaller} from "../src/PrecompileCaller.sol";

contract PrecompileBn128MulScript is Script {
    address constant PRECOMPILE_CALLER_ADDR = 0x224115411A570EE0C66d852084EB92f728f954ed;

    function run() external {
        vm.startBroadcast();

        PrecompileCaller c = PrecompileCaller(PRECOMPILE_CALLER_ADDR);

        // Multiply (1,2) by 2.
        bytes32 x = bytes32(uint256(1));
        bytes32 y = bytes32(uint256(2));
        bytes32 k = bytes32(uint256(2));

        console.log("=== BN128 Mul Test === (1,2) * 2");
        bytes memory out = c.callBn128Mul(x, y, k);
        console.logBytes(out); // 64 bytes

        vm.stopBroadcast();
    }
}
