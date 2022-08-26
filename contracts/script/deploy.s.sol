// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Script.sol";

import "../src/Rune.sol";

contract DeployScript is Script {
    function run() public {
        vm.startBroadcast();

        Rune rune = new Rune();

        vm.stopBroadcast();
    }
}
