// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {RevertHelper} from "../src/RevertHelper.sol";

contract HelperRevert is Script {
    address constant REVERT_TEST_ADDR = 0x2d93c2A44e7b33AbfAa3f0c3353C7dFE266736D5;
    address constant HELPER_ADDR = 0x1c3b44601BB528C1Cf0812397a70b9330864e996;

    function run() external {
        vm.startBroadcast();

        console.log("=== Helper Revert Test ===");
        console.log("Using RevertHelper to call a reverting function");

        RevertHelper helper = RevertHelper(HELPER_ADDR);
        bool result = helper.callRevertingFunction(REVERT_TEST_ADDR);

        console.log("Result:", result); // Should print false

        vm.stopBroadcast();
    }
}