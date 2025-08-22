// contracts/script/DeployNestedContracts.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Contract1} from "../src/Contract1.sol";
import {Contract2} from "../src/Contract2.sol";
import {Contract3} from "../src/Contract3.sol";
import {RevertTestContract} from "../src/RevertTestContract.sol";
import {RevertHelper} from "../src/RevertHelper.sol";
import {PrecompileCaller} from "../src/PrecompileCaller.sol";

contract DeployNestedContracts is Script {
    // Contract names for logging
    string[] private contractNames = [
        "Contract1",
        "Contract2",
        "Contract3",
        "RevertTestContract",
        "RevertHelper",
        "PrecompileCaller"
    ];

    // Expected contract addresses (deterministic on fresh blockchain)
    address[] private expectedAddresses = [
        0xc190dD4f971bf07A778dEB48C4Dc45dd64582f44, // Contract1
        0x9d86dbCcdf537F0a0BAF43160d2Ef1570d84E358, // Contract2
        0xC3536F63aB92bc7902dB5D57926c80f933121Bca, // Contract3
        0x2d93c2A44e7b33AbfAa3f0c3353C7dFE266736D5, // RevertTestContract
        0x1c3b44601BB528C1Cf0812397a70b9330864e996, // RevertHelper
        0x224115411A570EE0C66d852084EB92f728f954ed  // PrecompileCaller
    ];

    // Actual deployed addresses
    address[] private deployedAddresses;

    function setUp() public {}

    function run() public {
        // Check if all contracts are already deployed
        bool allDeployed = true;
        for (uint i = 0; i < expectedAddresses.length; i++) {
            if (!isContractDeployed(expectedAddresses[i])) {
                allDeployed = false;
                break;
            }
        }

        if (allDeployed) {
            console.log("Contracts already deployed:");
            for (uint i = 0; i < contractNames.length; i++) {
                console.log("  %s: %s", contractNames[i], expectedAddresses[i]);
            }
            return;
        }

        // Initialize the array
        deployedAddresses = new address[](expectedAddresses.length);

        vm.startBroadcast();

        // Deploy Contract1
        Contract1 contract1 = new Contract1();
        deployedAddresses[0] = address(contract1);
        console.log("%s deployed at: %s", contractNames[0], deployedAddresses[0]);

        // Deploy Contract2, passing Contract1's address
        Contract2 contract2 = new Contract2(deployedAddresses[0]);
        deployedAddresses[1] = address(contract2);
        console.log("%s deployed at: %s", contractNames[1], deployedAddresses[1]);

        // Deploy Contract3, passing Contract2's address
        Contract3 contract3 = new Contract3(deployedAddresses[1]);
        deployedAddresses[2] = address(contract3);
        console.log("%s deployed at: %s", contractNames[2], deployedAddresses[2]);

        // Deploy RevertTestContract
        RevertTestContract revertContract = new RevertTestContract();
        deployedAddresses[3] = address(revertContract);
        console.log("%s deployed at: %s", contractNames[3], deployedAddresses[3]);

        // Deploy RevertHelper
        RevertHelper revertHelper = new RevertHelper();
        deployedAddresses[4] = address(revertHelper);
        console.log("%s deployed at: %s", contractNames[4], deployedAddresses[4]);

        // Deploy PrecompileCaller
        PrecompileCaller precompileCaller = new PrecompileCaller();
        deployedAddresses[5] = address(precompileCaller);
        console.log("%s deployed at: %s", contractNames[5], deployedAddresses[5]);

        vm.stopBroadcast();

        // Verify addresses match expected
        bool allMatch = true;
        for (uint i = 0; i < expectedAddresses.length; i++) {
            if (deployedAddresses[i] != expectedAddresses[i]) {
                allMatch = false;
                console.log(
                    "WARNING: %s address mismatch! Expected: %s, Got: %s",
                    contractNames[i],
                    expectedAddresses[i],
                    deployedAddresses[i]
                );
            }
        }

        if (allMatch) {
            console.log("All contract addresses match expected values!");
        } else {
            console.log("Some contract addresses don't match expected values!");
        }
    }

    function isContractDeployed(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
}