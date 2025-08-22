// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PrecompileCaller} from "../src/PrecompileCaller.sol";

contract PrecompileBn128PairingScript is Script {
    address constant PRECOMPILE_CALLER_ADDR = 0x224115411A570EE0C66d852084EB92f728f954ed;

    function run() external {
        vm.startBroadcast();

        PrecompileCaller c = PrecompileCaller(PRECOMPILE_CALLER_ADDR);

        // Easiest valid input is the empty set of pairs; spec returns 1.
        bytes memory pairs = bytes("");

        console.log("=== BN128 Pairing Test === empty input (should return 1)");
        bytes memory out = c.callBn128Pairing(pairs);
        console.logBytes(out); // 32 bytes (0x...01)

        vm.stopBroadcast();
    }
}
