// contracts/script/SelfDestruct.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SelfDestructTest} from "../src/SelfDestructTest.sol";

contract SelfDestructScript is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy the contract with some initial ETH (0.1 ether)
        SelfDestructTest victim = new SelfDestructTest{value: 0.1 ether}();
        console.log("Deployed SelfDestructTest at:", address(victim));
        console.log("Contract balance:", address(victim).balance);

        // Create a beneficiary address (could be any address)
        address payable beneficiary = payable(address(0x1234567890123456789012345678901234567890));
        console.log("Beneficiary address:", beneficiary);
        console.log("Beneficiary balance before:", beneficiary.balance);

        // Call selfdestruct - THIS IS THE TRANSACTION WE WANT TO TRACE
        console.log("=== Calling SELFDESTRUCT ===");
        victim.destroy(beneficiary);

        // Note: After selfdestruct, the contract is marked for deletion
        console.log("Contract destroyed, funds sent to beneficiary");

        vm.stopBroadcast();
    }
}