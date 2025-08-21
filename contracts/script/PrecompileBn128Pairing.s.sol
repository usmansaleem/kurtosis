// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PrecompileCaller} from "../src/PrecompileCaller.sol";

contract PrecompileBn128PairingScript is Script {
    function run() external {
        vm.startBroadcast();

        PrecompileCaller c = new PrecompileCaller();

        // Easiest valid input is the empty set of pairs; spec returns 1.
        bytes memory pairs = bytes("");

        console.log("=== BN128 Pairing Test === empty input (should return 1)");
        bytes memory out = c.callBn128Pairing(pairs);
        console.logBytes(out); // 32 bytes (0x...01)

        vm.stopBroadcast();
    }
}
