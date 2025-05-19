// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Counter} from "../src/Counter.sol";
import {CounterCaller} from "../src/CounterCaller.sol";

contract DeployBothContracts is Script {
    Counter public counter;
    CounterCaller public counterCaller;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy the Counter contract
        counter = new Counter();
        console.log("Counter deployed at:", address(counter));

        // Deploy the CounterCaller contract, passing the Counter contract's address
        counterCaller = new CounterCaller(address(counter));
        console.log("CounterCaller deployed at:", address(counterCaller));

        vm.stopBroadcast();
    }
}