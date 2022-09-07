// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Script.sol";

import "forge-std/console2.sol";
import "../src/Alignment.sol";
import "../src/CombatVerifier.sol";
import "../src/Rune.sol";
import "../src/Seeker.sol";
import "../src/Dungeon.sol";

contract DeployScript is Script {
    function run() public {
        vm.startBroadcast();

        deploy();

        vm.stopBroadcast();
    }

    function deploy() public {
        Seeker seeker = new Seeker();
        seeker.setMaxSupply(1, 500);

        Rune rune = new Rune();
        address hasherAddress = deployPoseidon();
        Verifier combatVerifier = new Verifier();

        Dungeon dungeon = new Dungeon(
            address(seeker),
            address(rune),
            address(combatVerifier),
            hasherAddress
        );
    }

    function deployPoseidon() public returns (address) {
        bytes memory args = abi.encode(/*arg1, arg2*/);
        bytes memory contractBytes = vm.envBytes("POSEIDON_CONTRACT_BYTES");
        bytes memory bytecode = abi.encodePacked(contractBytes, args);
        address addr;
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        return addr;
    }
}
