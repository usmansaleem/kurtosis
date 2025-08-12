// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PrecompileCaller} from "../src/PrecompileCaller.sol";

contract PrecompileIdentityScript is Script {
    function run() external {
        vm.startBroadcast();

        PrecompileCaller c = new PrecompileCaller();

        // Non word-aligned payload to exercise padding (length = 11 bytes)
        bytes memory payload = hex"9fb37853deadbeef01aa55";
        console.log("=== Precompile Identity Test === len=%s", payload.length);

        // This is the tx we want traced (last tx in the script)
        c.callIdentity(payload);

        vm.stopBroadcast();
    }
}
