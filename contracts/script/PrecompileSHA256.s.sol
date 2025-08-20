// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PrecompileCaller} from "../src/PrecompileCaller.sol";

contract PrecompileSHA256Script is Script {
    function run() external {
        vm.startBroadcast();

        PrecompileCaller c = new PrecompileCaller();
        bytes memory payload = hex"f00dbeefdead"; // odd size to exercise memory slicing

        console.log("=== SHA256 Test === len=%s", payload.length);
        bytes memory out = c.callSHA256(payload);
        console.logBytes(out); // 32 bytes

        vm.stopBroadcast();
    }
}
