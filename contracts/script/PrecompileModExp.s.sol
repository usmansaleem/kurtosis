// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PrecompileCaller} from "../src/PrecompileCaller.sol";

contract PrecompileModExpScript is Script {
    function run() external {
        vm.startBroadcast();

        PrecompileCaller c = new PrecompileCaller();

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
