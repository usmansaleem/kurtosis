// contracts/script/SimpleTransfer.s.sol
// SPDX-License-Identifier: MIT or APACHE-2.0
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

contract SimpleTransferScript is Script {
    function run() external {
        vm.startBroadcast();

        // Simple EOA to EOA transfer
        address recipient = 0x6177843db3138ae69679A54b95cf345ED759450d;
        uint256 amount = 1.5 ether;

        console.log("=== Simple Transfer Test ===");
        console.log("From:", msg.sender);
        console.log("To:", recipient);
        console.log("Amount:", amount, "wei");

        // Execute the transfer and get transaction hash
        // Note: The tx hash will be available in the broadcast JSON file
        payable(recipient).transfer(amount);

        console.log("Transfer completed successfully");
        console.log("Transaction hash will be available in broadcast file");

        vm.stopBroadcast();
    }
}