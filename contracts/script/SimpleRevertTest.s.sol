// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {RevertContract} from "../src/RevertContract.sol";

contract SimpleRevertTest is Script {
    // Use existing deployed RevertContract
    address constant REVERT_CONTRACT_ADDR = 0x2d93c2A44e7b33AbfAa3f0c3353C7dFE266736D5;

    function run() external {
        vm.startBroadcast();

        console.log("=== Simple Revert Test ===");
        console.log("RevertContract address:", REVERT_CONTRACT_ADDR);

        // Load existing RevertContract
        RevertContract revertContract = RevertContract(REVERT_CONTRACT_ADDR);

        // Use try-catch without specifying return value
        try revertContract.alwaysRevert() {
            console.log("This should not be printed");
        } catch Error(string memory reason) {
            console.log("Caught revert with reason:", reason);
        } catch {
            console.log("Caught revert without specific reason");
        }

        vm.stopBroadcast();
    }
}