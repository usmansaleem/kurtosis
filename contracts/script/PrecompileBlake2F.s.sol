// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PrecompileCaller} from "../src/PrecompileCaller.sol";

contract PrecompileBlake2FScript is Script {
    function run() external {
        vm.startBroadcast();

        PrecompileCaller c = new PrecompileCaller();

        // Build 213-byte payload: rounds(4) + h(64) + m(128) + t(16) + final(1)
        // rounds is uint32 big-endian; final is 0x01 for last block.
        bytes memory input = new bytes(213);
        // rounds = 1
        input[0] = 0x00; input[1] = 0x00; input[2] = 0x00; input[3] = 0x01;
        // h, m, t are left as zeros
        // final = 0x01
        input[212] = 0x01;

        console.log("=== BLAKE2f Test === len=%s", input.length);
        bytes memory out = c.callBlake2F(input);
        console.logBytes(out); // 64 bytes

        vm.stopBroadcast();
    }
}
