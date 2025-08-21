// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PrecompileCaller} from "../src/PrecompileCaller.sol";

contract PrecompileBn128AddScript is Script {
    function run() external {
        vm.startBroadcast();

        PrecompileCaller c = new PrecompileCaller();

        // Use the small on-curve point (1,2) twice.
        bytes32 x = bytes32(uint256(1));
        bytes32 y = bytes32(uint256(2));

        console.log("=== BN128 Add Test === (1,2) + (1,2)");
        bytes memory out = c.callBn128Add(x, y, x, y);
        console.logBytes(out); // 64 bytes

        vm.stopBroadcast();
    }
}
