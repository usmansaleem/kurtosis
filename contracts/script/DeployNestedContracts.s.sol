// contracts/script/DeployNestedContracts.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Contract1} from "../src/Contract1.sol";
import {Contract2} from "../src/Contract2.sol";
import {Contract3} from "../src/Contract3.sol";

contract DeployNestedContracts is Script {
    // Expected contract addresses (deterministic on fresh blockchain)
    address constant EXPECTED_CONTRACT1 = 0xc190dD4f971bf07A778dEB48C4Dc45dd64582f44;
    address constant EXPECTED_CONTRACT2 = 0x9d86dbCcdf537F0a0BAF43160d2Ef1570d84E358;
    address constant EXPECTED_CONTRACT3 = 0xC3536F63aB92bc7902dB5D57926c80f933121Bca;

    Contract1 public contract1;
    Contract2 public contract2;
    Contract3 public contract3;

    function setUp() public {}

    function run() public {
        // Check if contracts are already deployed
        if (isContractDeployed(EXPECTED_CONTRACT1) &&
            isContractDeployed(EXPECTED_CONTRACT2) &&
            isContractDeployed(EXPECTED_CONTRACT3)) {

            console.log("Contracts already deployed:");
            console.log("  Contract1:", EXPECTED_CONTRACT1);
            console.log("  Contract2:", EXPECTED_CONTRACT2);
            console.log("  Contract3:", EXPECTED_CONTRACT3);
            return;
        }

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

        // Verify addresses match expected (on fresh blockchain)
        if (address(contract1) != EXPECTED_CONTRACT1 ||
            address(contract2) != EXPECTED_CONTRACT2 ||
            address(contract3) != EXPECTED_CONTRACT3) {

            console.log("WARNING: Contract addresses don't match expected values!");
            console.log("Expected Contract1:", EXPECTED_CONTRACT1, "Got:", address(contract1));
            console.log("Expected Contract2:", EXPECTED_CONTRACT2, "Got:", address(contract2));
            console.log("Expected Contract3:", EXPECTED_CONTRACT3, "Got:", address(contract3));
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