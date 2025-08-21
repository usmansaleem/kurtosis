// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PrecompileCaller} from "../src/PrecompileCaller.sol";

contract PrecompileRIPEMD160Script is Script {
    function run() external {
        vm.startBroadcast();

        PrecompileCaller c = new PrecompileCaller();
        bytes memory payload = hex"0102030405";

        console.log("=== RIPEMD160 Test === len=%s", payload.length);
        bytes memory out = c.callRIPEMD160(payload);
        console.logBytes(out); // 32 bytes (20B digest left-padded)

        vm.stopBroadcast();
    }
}
