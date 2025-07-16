// contracts/script/ContractCall.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Contract1} from "../src/Contract1.sol";
import {Contract2} from "../src/Contract2.sol";

contract ContractCallScript is Script {
    // Use existing deployed contracts
    address constant CONTRACT1_ADDR = 0xc190dD4f971bf07A778dEB48C4Dc45dd64582f44;
    address constant CONTRACT2_ADDR = 0x9d86dbCcdf537F0a0BAF43160d2Ef1570d84E358;

    function run() external {
        vm.startBroadcast();

        console.log("=== Contract Call Test (Contract2 -> Contract1) ===");
        console.log("Contract1 address:", CONTRACT1_ADDR);
        console.log("Contract2 address:", CONTRACT2_ADDR);

        // Load existing Contract2
        Contract2 contract2 = Contract2(CONTRACT2_ADDR);

        // Call Contract2.callSetValue which will internally call Contract1.setValue
        uint256 newValue = 888;
        console.log("Calling Contract2.callSetValue with value:", newValue);
        console.log("This will trigger: Contract2 -> Contract1.setValue");

        uint256 result = contract2.callSetValue(newValue);
        console.log("Result:", result);

        vm.stopBroadcast();
    }
}