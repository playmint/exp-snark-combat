// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./CombatVerifier.sol";
import "./Alignment.sol";
import "./Seeker.sol";
import "./Rune.sol";

import "forge-std/console2.sol"; // FIXME: remove

interface IPoseidonHasher {
    function poseidon(uint256[6] memory inp) external pure returns (uint256 out);
}

uint constant NUM_SEEKERS = 3;
uint constant NUM_TICKS = 100;

enum ActionKind {
    ENTER,
    EQUIP,
    DRINK,
    LEAVE
}

struct Slot {
    uint seekerID;
    uint hash;
}

struct CombatState {
    uint dungeonArmour;
    uint dungeonHealth;
    uint seekerArmour;
    uint seekerHealth;
    uint slot;
    uint tick;
    // proofy bits
    uint[2] pi_a;
    uint[2][2] pi_b;
    uint[2] pi_c;
}

contract Dungeon {

    event Action (
        ActionKind kind,
        uint8 slotID,
        uint8[7] args
    );

    Seeker seekerContract;
    Rune runeContract;
    Verifier combatVerifierContract;
    IPoseidonHasher hasher;

    // current battle config
    Alignment public dungeonAttackAlignment;
    Alignment public dungeonArmourAlignment;
    Alignment public dungeonHealthAlignment;
    Alignment public dungeonRewardRuneAlignment;
    uint8 public dungeonStrength = 10;
    uint public dungeonBattleStart;
    Slot[NUM_SEEKERS] public slots;
    bool[NUM_SEEKERS] public claimed;

    constructor(
        address _seekerContractAddr,
        address _runeContractAddr,
        address _combatVerifierContractAddr,
        address _hasherContractAddr
    ) {
        seekerContract = Seeker(_seekerContractAddr);
        runeContract = Rune(_runeContractAddr);
        combatVerifierContract = Verifier(_combatVerifierContractAddr);
        hasher = IPoseidonHasher(_hasherContractAddr);
    }

    function verifyState(CombatState memory state) public view returns (bool) {
        uint[NUM_SEEKERS+6] memory input; // 1x hash per seeker + selectedTick + selectedSeeker + 2x dungeon healths + 2x seeker healths
        uint i = 0;
        input[i] = state.dungeonArmour;
        i++;
        input[i] = state.dungeonHealth;
        i++;
        input[i] = state.seekerArmour;
        i++;
        input[i] = state.seekerHealth;
        i++;
        for (uint s=0; s<NUM_SEEKERS; s++) {
            input[i] = slots[s].hash;
            i++;
        }
        input[i] = state.slot;
        i++;
        input[i] = state.tick;
        i++;
        return combatVerifierContract.verifyProof(state.pi_a, state.pi_b, state.pi_c, input);
    }

    function claimRune(CombatState memory state) public {
        // seeker must actually be in the fight
        // find the seekerID from the given slotID
        Slot storage slot = slots[state.slot];
        require(slot.seekerID != 0, 'no seeker in slot');
        // ensure sender is owner of seeker in slot
        require(seekerContract.ownerOf(slot.seekerID) == tx.origin, 'not owner of seeker in slot');
        // check the given tick is in the past
        require(state.tick <= uint8(block.number - dungeonBattleStart), 'cannot verify the future');
        // check state valid
        require(verifyState(state), "invalid state");
        // check state.dungeonArmour damaged enough
        require(state.dungeonArmour < 30, 'dungeon armour not weak enough to grab rune');
        // check not already claimed
        require(!claimed[state.slot], 'already claimed the rune');
        // claim and mint rune
        claimed[state.slot] = true;
        runeContract.mint(tx.origin, dungeonRewardRuneAlignment);
    }

    function claimReward(CombatState memory state) public view {
        // check state valid
        require(verifyState(state), "invalid state");
        // check state.tick < block.number
        // check state.dungeonHealth == 0
        // check state.seekerHitpoints > 0
        // TODO: mint prize!
    }

    function send(
        ActionKind actionKind,
        uint8 seekerID,
        uint8 attackRuneID,
        uint8 armourRuneID,
        uint8 healthRuneID
    ) public {
        // ensure sender owns seeker
        require(seekerContract.ownerOf(seekerID) == tx.origin, 'not your seeker');
        // ensure state is settled
        // grab if seeker in a slot
        int8 slotID = getSeekerSlotID(seekerID);
        // perform action
        if (actionKind == ActionKind.ENTER) {
            // abort if seeker already in dungeon
            require(slotID == -1, "already in dungeon");
            // find a free seeker slot
            slotID = getFreeSlotID();
            require(slotID != -1, "dungeon is full");
            // now that the state is settled, we can mess with the fight config...
            setSeekerSlot(
                actionKind,
                uint8(slotID),
                seekerID,
                attackRuneID,
                armourRuneID,
                healthRuneID
            );
        } else if(actionKind == ActionKind.LEAVE) {
            // abort if seeker not in dungeon
            require(slotID > -1, "not in dungeon");
            // abort for now
            revert('not implemented');
            // empty slot
            // clearSeekerSlot(uint8(slot));
        } else if(actionKind == ActionKind.EQUIP) {
            // abort if seeker not in dungeon
            require(slotID > -1, "not in dungeon");
            // update slot data
            setSeekerSlot(
                actionKind,
                uint8(slotID),
                seekerID,
                attackRuneID,
                armourRuneID,
                healthRuneID
            );
        } else if(actionKind == ActionKind.DRINK) {
            // TODO
            revert('not implemented');
        }
    }

    function resetBattle(
        Alignment _dungeonAttackAlignment,
        Alignment _dungeonArmourAlignment,
        Alignment _dungeonHealthAlignment,
        Alignment _dungeonRewardRuneAlignment
    ) public {
        dungeonBattleStart = block.number;
        dungeonAttackAlignment = _dungeonAttackAlignment;
        dungeonArmourAlignment = _dungeonArmourAlignment;
        dungeonHealthAlignment = _dungeonHealthAlignment;
        dungeonRewardRuneAlignment = _dungeonRewardRuneAlignment;
        for (uint8 i=0; i<NUM_SEEKERS; i++) {
            clearSeekerSlot(i);
        }
    }

    function clearSeekerSlot(
        uint8 slotID
    ) private {
        slots[slotID].seekerID = 0;
        slots[slotID].hash = 0;
    }

    function getSeekerSlot(
        uint8 slotID
    ) private view returns (Slot storage) {
        return slots[slotID];
    }

    function getSeekerSlotHash(
        uint8 slotID
    ) public view returns (uint) {
        return slots[slotID].hash;
    }

    function setSeekerSlot(
        ActionKind actionKind,
        uint8 slotID,
        uint8 seekerID,
        uint8 attackRuneID,
        uint8 armourRuneID,
        uint8 healthRuneID
    ) private {
        // get the stats values
        SeekerData memory data = seekerContract.getData(seekerID);
        // get rune alignments
        Alignment seekerAttackAlignment = getVerifiedRuneAlignment(attackRuneID);
        Alignment seekerArmourAlignment = getVerifiedRuneAlignment(armourRuneID);
        Alignment seekerHealthAlignment = getVerifiedRuneAlignment(healthRuneID);
        // calc and update the attack stats including rune mods
        commitAction(actionKind, slotID, [
            uint8(block.number - dungeonBattleStart), // TODO: overflow likely
            uint8(dungeonStrength + alignmentBonus(dungeonAttackAlignment, seekerArmourAlignment)),
            uint8(dungeonStrength + alignmentBonus(dungeonAttackAlignment, seekerHealthAlignment)),
            uint8(data.strength + alignmentBonus(seekerAttackAlignment, dungeonArmourAlignment)),
            uint8(data.strength + alignmentBonus(seekerAttackAlignment, dungeonHealthAlignment)),
            0,
            0
        ]);
        // update the seekerID if not set
        if (slots[slotID].seekerID == 0) {
            slots[slotID].seekerID = seekerID;
        }
    }

    // getVerifiedRuneAlignment checks that the sender owns the runes and
    // returns the alignment of that rune type
    // [!] TODO: we don't check people aren't using same rune multiple times
    //     let's just call that a feature for now
    function getVerifiedRuneAlignment(uint8 runeTypeID) public view returns (Alignment) {
        if (runeTypeID == 0) {
            return Alignment.NONE;
        }
        // abort if seeker not own the given rune
        require(runeContract.ownerOf(runeTypeID) == msg.sender, "does not own rune");
        return runeContract.getAlignment(runeTypeID);
    }

    // alignmentBonus works out the attack boost provided between attack/defense alignments
    // see: https://www.notion.so/playmint/Attributes-Alignment-8b698d3c2831456e97f1606dc7e4f47b
    function alignmentBonus(Alignment sourceAlignment, Alignment targetAlignment) public pure returns (uint8) {
        if (sourceAlignment == Alignment.LIGHT) {
            if (targetAlignment == Alignment.DARK) {
                return 3;
            } else if (targetAlignment == Alignment.ARCANE) {
                return 2;
            } else {
                return 1;
            }
        } else if (sourceAlignment == Alignment.DARK) {
            if (targetAlignment == Alignment.ORDER) {
                return 2;
            } else if (targetAlignment == Alignment.ARCANE) {
                return 3;
            } else {
                return 1;
            }
        } else if (sourceAlignment == Alignment.ORDER) {
            if (targetAlignment == Alignment.LIGHT) {
                return 2;
            } else if (targetAlignment == Alignment.CHAOS) {
                return 3;
            } else {
                return 1;
            }
        } else if (sourceAlignment == Alignment.CHAOS) {
            if (targetAlignment == Alignment.LIGHT) {
                return 3;
            } else if (targetAlignment == Alignment.DARK) {
                return 2;
            } else {
                return 1;
            }
        } else if (sourceAlignment == Alignment.ARCANE) {
            if (targetAlignment == Alignment.ORDER) {
                return 3;
            } else if (targetAlignment == Alignment.CHAOS) {
                return 2;
            } else {
                return 1;
            }
        }
        return 0;
    }

    // getSlotID returns the slot index for the given seeker ID or -1 is not
    // [!]: I think this can be replaced with a proof, but not sure if worth it
    function getSeekerSlotID(uint seekerID) public view returns (int8) {
        for (uint i=0; i<NUM_SEEKERS; i++) {
            if (slots[i].seekerID == seekerID) {
                return int8(uint8(i));
            }
        }
        return -1;
    }

    // getFreeSlotID returns an available slot or -1 if full
    function getFreeSlotID() public view returns (int8) {
        for (uint i=0; i<NUM_SEEKERS; i++) {
            if (slots[i].seekerID == 0) {
                return int8(uint8(i));
            }
        }
        return -1;
    }

    // commitAction logs the user intent.
    // update the hash of the seeker/slot actions on-chain
    // log the action data to allow clients to rebuild it
    function commitAction(ActionKind actionKind, uint8 slotID, uint8[7] memory args) public {
        // update the hash
        slots[slotID].hash = hasher.poseidon([
            slots[slotID].hash,
            args[1],
            args[2],
            args[3],
            args[4],
            args[0] // tick
        ]);
        // log the action data
        emit Action(
            actionKind,
            slotID,
            args
        );
    }

}
