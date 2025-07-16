// contracts/script/CreateContract.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Contract1} from "../src/Contract1.sol";
import {Contract2} from "../src/Contract2.sol";
import {Contract3} from "../src/Contract3.sol";

contract CreateContractScript is Script {
    Contract1 public contract1;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        console.log("=== Create Contract Test ===");
        // Deploy Contract1
        contract1 = new Contract1();
        console.log("Contract1 deployed at:", address(contract1));
        vm.stopBroadcast();
    }
}