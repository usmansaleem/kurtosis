// contracts/script/NestedContractCall.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Contract1} from "../src/Contract1.sol";
import {Contract2} from "../src/Contract2.sol";
import {Contract3} from "../src/Contract3.sol";

contract NestedContractCallScript is Script {
    // Use existing deployed contracts
    address constant CONTRACT1_ADDR = 0xc190dD4f971bf07A778dEB48C4Dc45dd64582f44;
    address constant CONTRACT2_ADDR = 0x9d86dbCcdf537F0a0BAF43160d2Ef1570d84E358;
    address constant CONTRACT3_ADDR = 0xC3536F63aB92bc7902dB5D57926c80f933121Bca;

    function run() external {
        vm.startBroadcast();

        console.log("=== Nested Contract Call Test (Contract3 -> Contract2 -> Contract1) ===");
        console.log("Contract1 address:", CONTRACT1_ADDR);
        console.log("Contract2 address:", CONTRACT2_ADDR);
        console.log("Contract3 address:", CONTRACT3_ADDR);

        // Load existing Contract3
        Contract3 contract3 = Contract3(CONTRACT3_ADDR);

        // Call Contract3.nestedSetValue which will trigger:
        // Contract3 -> Contract2.callSetValue -> Contract1.setValue
        uint256 newValue = 999;
        console.log("Calling Contract3.nestedSetValue with value:", newValue);
        console.log("This will trigger: Contract3 -> Contract2 -> Contract1.setValue");

        uint256 result = contract3.nestedSetValue(newValue);
        console.log("Result:", result);

        vm.stopBroadcast();
    }
}