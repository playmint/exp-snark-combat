// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./CombatVerifier.sol";
import "./Alignment.sol";
import "./Seeker.sol";
import "./Rune.sol";

import "forge-std/console2.sol"; // FIXME: remove

interface IPoseidonHasher {
    function poseidon(uint256[5] memory inp) external pure returns (uint256 out);
}

enum Action {
    ENTER,
    EQUIP,
    DRINK,
    LEAVE
}

struct Slot {
    uint seekerID;
    uint hash;
    uint[] actions;
}

struct CombatProof {
    uint[2] a;
    uint[2][2] b;
    uint[2] c;
}

struct CombatState {
    uint dungeonArmour;
    uint dungeonHealth;
    uint seekerArmour;
    uint seekerHealth;
    uint seekerSlot;
}
    uint constant NUM_SEEKERS = 10;
    uint constant NUM_TICKS = 100;

contract Dungeon {


    Seeker seekerContract;
    Rune runeContract;
    Verifier combatVerifierContract;
    IPoseidonHasher hasher;

    // current battle config
    Alignment public dungeonAttackAlignment;
    Alignment public dungeonArmourAlignment;
    Alignment public dungeonHealthAlignment;
    uint8 public dungeonStrength = 2;
    uint public dungeonBattleStart;
    Slot[NUM_SEEKERS] public slots;

    constructor(
        address _seekerContractAddr,
        address _runeContractAddr,
        address _combatVerifierContractAddr,
        address _hasherContractAddr,
        Alignment _dungeonAttackAlignment,
        Alignment _dungeonArmourAlignment,
        Alignment _dungeonHealthAlignment
    ) {
        seekerContract = Seeker(_seekerContractAddr);
        runeContract = Rune(_runeContractAddr);
        combatVerifierContract = Verifier(_combatVerifierContractAddr);
        hasher = IPoseidonHasher(_hasherContractAddr);
        dungeonAttackAlignment = _dungeonAttackAlignment;
        dungeonArmourAlignment = _dungeonArmourAlignment;
        dungeonHealthAlignment = _dungeonHealthAlignment;
        resetBattle();
    }

    function verifyState(CombatState memory state, CombatProof memory proof) public view returns (bool) {
        uint[NUM_SEEKERS+5] memory input;
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
        input[i] = state.seekerSlot;
        i++;
        return combatVerifierContract.verifyProof(proof.a, proof.b, proof.c, input);
    }

    function claimAttackRune(CombatState memory state, CombatProof memory proof) public view {
        // check state valid
        require(verifyState(state, proof), "invalid state");
        // check state.tick < block.number
        // check state.dungeonArmour < 50
        // check not already claimed
        // mint rune
    }

    function claimReward(CombatState memory state, CombatProof memory proof) public view {
        // check state valid
        require(verifyState(state, proof), "invalid state");
        // check state.tick < block.number
        // check state.dungeonHealth == 0
        // check state.seekerHitpoints > 0
        // mint prize
    }

    function send(
        Action action,
        uint8 seekerID,
        uint8 attackRuneID,
        uint8 armourRuneID,
        uint8 healthRuneID
    ) public {
        // ensure sender owns seeker
        require(seekerContract.ownerOf(seekerID) == tx.origin, 'not your seeker');
        // ensure state is settled
        // updateState(state, proof);
        // grab if seeker in a slot
        int8 slotID = getSeekerSlotID(seekerID);
        // perform action
        if (action == Action.ENTER) {
            // abort if seeker already in dungeon
            require(slotID == -1, "already in dungeon");
            // find a free seeker slot
            slotID = getFreeSlotID();
            require(slotID != -1, "dungeon is full");
            //
            // now that the state is settled, we can mess with the fight config...
            setSeekerSlot(
                action,
                uint8(slotID),
                seekerID,
                attackRuneID,
                armourRuneID,
                healthRuneID
            );
        } else if(action == Action.LEAVE) {
            // abort if seeker not in dungeon
            require(slotID > -1, "not in dungeon");
            // abort for now
            revert('not implemented');
            // empty slot
            // clearSeekerSlot(uint8(slot));
        } else if(action == Action.EQUIP) {
            // abort if seeker not in dungeon
            require(slotID > -1, "not in dungeon");
            // update slot data
            setSeekerSlot(
                action,
                uint8(slotID),
                seekerID,
                attackRuneID,
                armourRuneID,
                healthRuneID
            );
        } else if(action == Action.DRINK) {
            // TODO
            revert('not implemented');
        }
    }

    function resetBattle() public {
        dungeonBattleStart = block.number;
        for (uint8 i=0; i<NUM_SEEKERS; i++) {
            clearSeekerSlot(i);
        }
    }

    function clearSeekerSlot(
        uint8 slotID
    ) private {
        slots[slotID].seekerID = 0;
        slots[slotID].hash = 17257659134915904690545691500174578522357305172162686335509530090665176343474; // hash of the zero value
        slots[slotID].actions = new uint[](0);
    }

    function getSeekerSlot(
        uint8 slotID
    ) public view returns (Slot memory) {
        return slots[slotID];
    }

    function setSeekerSlot(
        Action action,
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
        appendAction(action, slotID, [
            uint8(block.number - dungeonBattleStart), // TODO: overflow likely
            uint8(data.strength + alignmentBonus(seekerAttackAlignment, dungeonArmourAlignment)),
            uint8(data.strength + alignmentBonus(seekerAttackAlignment, dungeonHealthAlignment)),
            uint8(dungeonStrength + alignmentBonus(dungeonAttackAlignment, seekerArmourAlignment)),
            uint8(dungeonStrength + alignmentBonus(dungeonAttackAlignment, seekerHealthAlignment)),
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
            }
        } else if (sourceAlignment == Alignment.DARK) {
            if (targetAlignment == Alignment.ORDER) {
                return 2;
            } else if (targetAlignment == Alignment.ARCANE) {
                return 3;
            }
        } else if (sourceAlignment == Alignment.ORDER) {
            if (targetAlignment == Alignment.LIGHT) {
                return 2;
            } else if (targetAlignment == Alignment.CHAOS) {
                return 3;
            }
        } else if (sourceAlignment == Alignment.CHAOS) {
            if (targetAlignment == Alignment.LIGHT) {
                return 3;
            } else if (targetAlignment == Alignment.DARK) {
                return 2;
            }
        } else if (sourceAlignment == Alignment.ARCANE) {
            if (targetAlignment == Alignment.ORDER) {
                return 3;
            } else if (targetAlignment == Alignment.CHAOS) {
                return 2;
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

    // adds logs of the action to a list of all actions
    // [!]: very gas expensive!
    //      there is a potentially large gas saving if we:
    //        1) relied on tx calldata for storage of actions
    //        2) calc this hash off-chain and verify the transition with a proof
    function appendAction(Action action, uint slotID, uint8[7] memory args) public {
        slots[slotID].actions.push( encodeAction(action, args) );
        slots[slotID].hash = calcSlotHash(slotID);
    }

    function calcSlotHash(uint slotID) private view returns (uint256){
        Slot storage slot = slots[slotID];

        uint inputValuesHash = 0;
        Action action;
        uint8[7] memory args;

        uint8 t = uint8(NUM_TICKS);
        uint8 untilTick;
        uint8 dungeonAttackArmour;
        uint8 dungeonAttackHealth;
        uint8 seekerAttackArmour;
        uint8 seekerAttackHealth;
        for (uint i=slot.actions.length; i>0; i--) {
            (action, args) = decodeAction(slot.actions[i-1]);
            if (action == Action.ENTER || action == Action.EQUIP) {
                untilTick = i==1 ? 0 : args[0];
                dungeonAttackArmour = args[1];
                dungeonAttackHealth = args[2];
                seekerAttackArmour = args[3];
                seekerAttackHealth = args[4];
                while (t >= untilTick+1) {
                    inputValuesHash = hasher.poseidon([
                        inputValuesHash,
                        dungeonAttackArmour,
                        dungeonAttackHealth,
                        seekerAttackArmour,
                        seekerAttackHealth
                    ]);
                    t--;
                }
            }
        }
        return inputValuesHash;
    }

    // pack an action and associated args into a single uint256
    function encodeAction(Action action, uint8[7] memory args) public pure returns (uint256) {
        return uint256(action)
        | (uint256(action) << 8)
        | (uint256(args[0]) << 21)
        | (uint256(args[1]) << 34)
        | (uint256(args[2]) << 47)
        | (uint256(args[3]) << 60)
        | (uint256(args[4]) << 73)
        | (uint256(args[5]) << 86)
        | (uint256(args[6]) << 99);
    }

    // decodeAction unpacks an action and args encoded by encodeAction()
    function decodeAction(uint256 packed) public pure returns (Action action, uint8[7] memory args) {
        action = Action(uint8((packed >> 8) & 0x1fff));
        args[0] = uint8((packed >> 21) & 0x1fff);
        args[1] = uint8((packed >> 34) & 0x1fff);
        args[2] = uint8((packed >> 47) & 0x1fff);
        args[3] = uint8((packed >> 60) & 0x1fff);
        args[4] = uint8((packed >> 73) & 0x1fff);
        args[5] = uint8((packed >> 86) & 0x1fff);
        args[6] = uint8((packed >> 99) & 0x1fff);
    }
}
