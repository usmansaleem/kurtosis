// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PrecompileCaller} from "../src/PrecompileCaller.sol";

contract PrecompileRIPEMD160Script is Script {
    address constant PRECOMPILE_CALLER_ADDR = 0x224115411A570EE0C66d852084EB92f728f954ed;

    function run() external {
        vm.startBroadcast();

        PrecompileCaller c = PrecompileCaller(PRECOMPILE_CALLER_ADDR);
        bytes memory payload = hex"0102030405";

        console.log("=== RIPEMD160 Test === len=%s", payload.length);
        bytes memory out = c.callRIPEMD160(payload);
        console.logBytes(out); // 32 bytes (20B digest left-padded)

        vm.stopBroadcast();
    }
}
