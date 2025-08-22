// SPDX-License-Identifier: MIT
// contracts/script/PrecompileIdentity.s.sol
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PrecompileCaller} from "../src/PrecompileCaller.sol";

contract PrecompileIdentityScript is Script {
    address constant PRECOMPILE_CALLER_ADDR = 0x224115411A570EE0C66d852084EB92f728f954ed;

    function run() external {
        vm.startBroadcast();

        // load already deployed contract
        PrecompileCaller c = PrecompileCaller(PRECOMPILE_CALLER_ADDR);

        // Non word-aligned payload to exercise padding (length = 11 bytes)
        bytes memory payload = hex"9fb37853deadbeef01aa55";
        console.log("=== Precompile Identity Test === len=%s", payload.length);

        // This is the tx we want traced (last tx in the script)
        c.callIdentity(payload);

        vm.stopBroadcast();
    }
}
