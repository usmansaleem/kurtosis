// contracts/script/SimpleContractCall.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Contract1} from "../src/Contract1.sol";

contract SimpleContractCallScript is Script {
    // Use existing deployed Contract1
    address constant CONTRACT1_ADDR = 0xc190dD4f971bf07A778dEB48C4Dc45dd64582f44;

    function run() external {
        vm.startBroadcast();

        console.log("=== Simple Contract Call Test ===");
        console.log("Contract1 address:", CONTRACT1_ADDR);

        // Load existing Contract1
        Contract1 contract1 = Contract1(CONTRACT1_ADDR);

        // Call Contract1.setValue directly
        uint256 newValue = 777;
        console.log("Calling Contract1.setValue with value:", newValue);

        uint256 result = contract1.setValue(newValue);
        console.log("Result:", result);

        vm.stopBroadcast();
    }
}