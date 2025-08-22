// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PrecompileCaller} from "../src/PrecompileCaller.sol";

contract PrecompileECRecoverScript is Script {
    address constant PRECOMPILE_CALLER_ADDR = 0x224115411A570EE0C66d852084EB92f728f954ed;

    function run() external {
        vm.startBroadcast();

        PrecompileCaller c = PrecompileCaller(PRECOMPILE_CALLER_ADDR);

        // Make a real signature so the precompile returns a nonzero address.
        uint256 pk = 0xA11CE; // any dev key
        address signer = vm.addr(pk);
        bytes32 msgHash = keccak256("hello precompile");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, msgHash);

        console.log("=== ECRecover Test ===");
        console.log("signer:", signer);

        bytes memory out = c.callECRecover(msgHash, v, r, s);
        // The returned 32 bytes contain the address in the rightmost 20 bytes.
        console.logBytes(out);

        vm.stopBroadcast();
    }
}
