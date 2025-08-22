// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PrecompileCaller} from "../src/PrecompileCaller.sol";

contract PrecompileModExpScript is Script {
    address constant PRECOMPILE_CALLER_ADDR = 0x224115411A570EE0C66d852084EB92f728f954ed;

    function run() external {
        vm.startBroadcast();

        PrecompileCaller c = PrecompileCaller(PRECOMPILE_CALLER_ADDR);

        // Compute 2^5 mod 19 => 32 mod 19 = 13 (0x0d). Small lengths to keep gas tiny.
        bytes memory base = hex"02";
        bytes memory exp  = hex"05";
        bytes memory modn = hex"13";

        console.log("=== ModExp Test === base=2 exp=5 mod=19");
        bytes memory out = c.callModExp(base, exp, modn);
        console.logBytes(out); // length = len(modn) (=1)

        vm.stopBroadcast();
    }
}
