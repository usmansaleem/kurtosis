// contracts/script/Delegatecall.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {DelegateImpl} from "../src/DelegateImpl.sol";
import {DelegateProxy} from "../src/DelegateProxy.sol";

contract DelegatecallScript is Script {
    function run() external {
        vm.startBroadcast();
        DelegateImpl impl = new DelegateImpl();
        DelegateProxy proxy = new DelegateProxy(address(impl));

        console.log("=== Delegatecall Test ===");
        proxy.dset(7); // child frame: type=DELEGATECALL, no "value" field
        vm.stopBroadcast();
    }
}
