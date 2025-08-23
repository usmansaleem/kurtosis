// contracts/script/InsufficientBalance.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {FailedCallsTest} from "../src/FailedCallsTest.sol";

contract InsufficientBalanceScript is Script {
    function run() external {
        vm.startBroadcast();

        FailedCallsTest test = new FailedCallsTest();
        console.log("Deployed FailedCallsTest at:", address(test));

        address target = address(0x1234567890123456789012345678901234567890);

        console.log("=== Testing Insufficient Balance ===");
        // This should fail with INSUFFICIENT_BALANCE
        test.testInsufficientBalance(target);
        console.log("Call attempted (should fail silently)");

        vm.stopBroadcast();
    }
}