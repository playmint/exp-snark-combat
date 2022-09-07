// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Alignment.sol";
import "../src/CombatVerifier.sol";
import "../src/Rune.sol";
import "../src/Seeker.sol";
import "../src/Dungeon.sol";

contract DungeonTest is Test {
    Dungeon public dungeon;
    Seeker public seeker;

    function setUp() public {
        seeker = new Seeker();
        seeker.setMaxSupply(1, 500);

        Rune rune = new Rune();
        address hasherAddress = setUpPoseidon();
        Verifier combatVerifier = new Verifier();

        dungeon = new Dungeon(
            address(seeker),
            address(rune),
            address(combatVerifier),
            hasherAddress
        );
    }

    function setUpPoseidon() public returns (address) {
        bytes memory args = abi.encode(/*arg1, arg2*/);
        bytes memory contractBytes = vm.envBytes("POSEIDON_CONTRACT_BYTES");
        bytes memory bytecode = abi.encodePacked(contractBytes, args);
        address addr;
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        return addr;
    }

    function setUpSeeker(uint8 str) public returns (uint) {
        // mint a seeker
        uint8[8] memory attrs = [
            str, // str
            2, // tough
            3, // dex
            4, // speed
            5, // vit
            6, // endur
            7, // order
            0 // corruption (ignored)
        ];
        return seeker.mint(
            msg.sender,
            1,
            attrs
        );
    }

    function testActionEnter() public {
        // mint a seeker
        uint seekerID = setUpSeeker(2);
        // start the battle
        vm.roll(100);
        dungeon.resetBattle(
            Alignment.LIGHT,
            Alignment.LIGHT,
            Alignment.LIGHT,
            Alignment.DARK
        );
        // enter the dungeon
        vm.roll(105);
        dungeon.send(
            ActionKind.ENTER,
            uint8(seekerID),
            0,
            0,
            0
        );
        // expect to now have a seeker slotID
        int8 slotID = dungeon.getSeekerSlotID(seekerID);
        assertTrue(slotID != -1, 'expect seeker to have a slot');
        uint slotHash = dungeon.getSeekerSlotHash(uint8(slotID));
        // expect hash to be set
        assertTrue(slotHash != 0, 'should have computed hash of actions');
    }

    function testClaimRune() public {
        // roll forward to a larger block num and start battle
        uint blk = 13773000;
        vm.roll(blk);
        dungeon.resetBattle(
            Alignment.LIGHT,
            Alignment.LIGHT,
            Alignment.LIGHT,
            Alignment.DARK
        );
        // add seekers to all but one slots (replicating what generate_input.js does)
        vm.roll(++blk);
        uint seekerID;
        for (uint s=0; s<NUM_SEEKERS-1; s++) {
            seekerID = setUpSeeker(1);
            dungeon.send(
                ActionKind.ENTER,
                uint8(seekerID),
                0,
                0,
                0
            );
        }

        // emulate someone passing in a proof...
        // see Makefile for where these environment variables are set
        // the come from executing the proover from the command line
        blk += 100;
        vm.roll(++blk);
        uint256[] memory inputs = vm.envUint("PROOF_INPUTS", ",");
        uint256[] memory pi_a = vm.envUint("PROOF_PI_A", ",");
        uint256[] memory pi_b_0 = vm.envUint("PROOF_PI_B_0", ",");
        uint256[] memory pi_b_1 = vm.envUint("PROOF_PI_B_1", ",");
        uint256[] memory pi_c = vm.envUint("PROOF_PI_C", ",");
        CombatState memory state = CombatState({
            dungeonArmour: inputs[0],
            dungeonHealth: inputs[1],
            seekerArmour: inputs[2],
            seekerHealth: inputs[3],
            slot: 0,
            tick: 99,
            pi_a: [pi_a[0], pi_a[1]],
            pi_b: [
               [pi_b_0[1], pi_b_0[0]],
               [pi_b_1[1], pi_b_1[0]]
            ],
            pi_c: [pi_c[0], pi_c[1]]
        });

        dungeon.claimRune(state);

    }

}
