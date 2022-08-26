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
            hasherAddress,
            Alignment.LIGHT, // _dungeonAttackAlignment,
            Alignment.LIGHT, // _dungeonArmourAlignment,
            Alignment.LIGHT // _dungeonHealthAlignment
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

    function setUpSeeker() public returns (uint) {
        // mint a seeker
        uint8[8] memory attrs = [
            1, // str
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
        uint seekerID = setUpSeeker();
        // start the battle
        vm.roll(100);
        dungeon.resetBattle();
        // enter the dungeon
        vm.roll(105);
        dungeon.send(
            Action.ENTER,
            uint8(seekerID),
            0,
            0,
            0
        );
        // expect to now have a seeker slotID
        int8 slotID = dungeon.getSeekerSlotID(seekerID);
        assertTrue(slotID != -1, 'expect seeker to have a slot');
        Slot memory slot = dungeon.getSeekerSlot(uint8(slotID));
        // expect the action to be added to slot
        assertEq(slot.actions.length, 1, 'expect one action in the slot');
        // expect correct action logged
        (Action action0, uint8[7] memory args) = dungeon.decodeAction(slot.actions[0]);
        assertEq(uint(action0), uint(Action.ENTER), 'should be ENTER action');
        // expect the attack values to be based on seeker stats
        SeekerData memory data = seeker.getData(seekerID);
        assertEq(args[0], 5, 'should be 5 ticks since battle start');
        assertEq(args[1], data.strength, 'should be base strength from seeker');
        assertEq(args[2], data.strength, 'should be base strength from seeker');
        assertEq(args[3], dungeon.dungeonStrength(), 'should be base strength from dungeon');
        assertEq(args[4], dungeon.dungeonStrength(), 'should be base strength from dungeon');
        // expect hash to be set
        assertTrue(slot.hash != 0, 'should have computed hash of actions');
    }

    function testProof() public {
        // roll forward to a larger block num
        uint blk = 13773000;
        vm.roll(blk);
        // add seekers to all slots (replicating what generate_input.js does)
        uint seekerID;
        dungeon.resetBattle();
        for (uint s=0; s<NUM_SEEKERS; s++) {
            seekerID = setUpSeeker();
            dungeon.send(
                Action.ENTER,
                uint8(seekerID),
                0,
                0,
                0
            );
        }

        // pick slot (same as generate_input.js)
        int8 slotID = 0;

        // emulate someone passing in a proof...
        // see Makefile for where these environment variables are set
        // the come from executing the proover from the command line
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
            seekerSlot: uint256(uint8(slotID))
        });
        CombatProof memory proof = CombatProof({
            a: [pi_a[0], pi_a[1]],
            b: [
               [pi_b_0[1], pi_b_0[0]],
               [pi_b_1[1], pi_b_1[0]]
            ],
            c: [pi_c[0], pi_c[1]]
        });

        assertTrue(dungeon.verifyState(state, proof), 'expected proof to be legit');

    }

}
