// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Contract1} from "../src/Contract1.sol";
import {Contract2} from "../src/Contract2.sol";
import {Contract3} from "../src/Contract3.sol";

contract DeployNestedContracts is Script {
    Contract1 public contract1;
    Contract2 public contract2;
    Contract3 public contract3;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy Contract1
        contract1 = new Contract1();
        console.log("Contract1 deployed at:", address(contract1));

        // Deploy Contract2, passing Contract1's address
        contract2 = new Contract2(address(contract1));
        console.log("Contract2 deployed at:", address(contract2));

        // Deploy Contract3, passing Contract2's address
        contract3 = new Contract3(address(contract2));
        console.log("Contract3 deployed at:", address(contract3));

        vm.stopBroadcast();
    }
}