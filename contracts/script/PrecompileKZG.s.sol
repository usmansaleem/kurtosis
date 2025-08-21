// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PrecompileCaller} from "../src/PrecompileCaller.sol";

/// NOTE: Only works on Cancun/Deneb-enabled chains (EIP-4844).
/// You must supply a properly encoded point-evaluation input per the spec/test vectors.
/// This script shows the harness; fill `payload` with a valid vector if your node supports it.
contract PrecompileKZGScript is Script {
    function run() external {
        vm.startBroadcast();

        PrecompileCaller c = new PrecompileCaller();

        bytes memory payload = hex""; // TODO: insert a real test vector
        console.log("=== KZG Point Eval Test === len=%s", payload.length);

        // This will likely revert unless payload is valid & chain supports 0x0a.
        // bytes memory out = c.callKZG(payload);
        // console.logBytes(out);

        vm.stopBroadcast();
    }
}
