// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../Seeker.sol";

uint constant SEEKER_CAP = 3; // CONFIG:SEEKER_CAP
uint constant NUM_TICKS = 100; // CONFIG:NUM_TICKS

interface IPoseidonHasher {
    function poseidon(
        uint256[2] memory inp
    ) external pure returns (uint256 out);
}

contract CombatSession is Ownable {
    enum CombatAction {
        JOIN,
        LEAVE,
        EQUIP
    }

    struct CombatTileData {
        uint16 resonance;
        uint16 health;
        uint16 attack;
        address sessionReward;
        uint256 sessionSupply;
        address bonusReward;
        uint256 bonusSupply;
        uint8 sessionDuration;
        uint256 regenDuration;
        uint256 maxRespawn;
        uint8 respawnSupplyDecayPerc;
        uint256 minDecayedSupply;
    }

    struct Slot {
        uint seekerID;
        uint16 claimed;
        uint256 hash;
    }

    struct SlotConfig {
        CombatAction action;
        uint8 tick;
        // seeker stats
        uint8 resonance; // 0
        uint8 health; // 1
        uint8 attack; // 2
        uint8 criticalHit; // 3
    }

    event SlotUpdated(uint8 slotID, SlotConfig cfg);

    // --- CONTRACT PROPERTIES

    Seeker seekerContract;
    IPoseidonHasher hasher;

    CombatTileData public tileData;
    Slot[SEEKER_CAP] public slots;
    uint public startBlock;

    // ---- //

    constructor(
        Seeker _seekerContract,
        IPoseidonHasher _hasherContract,
        CombatTileData memory _tileData
    ) {
        seekerContract = _seekerContract;
        hasher = _hasherContract;

        tileData = _tileData;
        startBlock = block.number;
    }

    // -- ACTIONS

    function join(uint seekerID) onlyOwner public {
        (uint8 slotID, bool ok) = getSeekerSlotID(seekerID);
        if (!ok) {
            (slotID, ok) = getFreeSlotID();
            require(ok, "CombatSession::join: No slots available");
        }

        updateSlot(slotID, seekerID, CombatAction.JOIN);
    }

    function leave(uint seekerID) onlyOwner public {
        (uint8 slotID, bool ok) = getSeekerSlotID(seekerID);

        require(ok, "CombatSession::leave: Seeker not found");

        updateSlot(slotID, seekerID, CombatAction.LEAVE);
    }

    function updateSlot(uint8 slotID, uint seekerID, CombatAction action) private {
        // Check if session is valid. More to do around this regarding regen
        uint tick = block.number - startBlock;
        require(
            tick < NUM_TICKS,
            "CombatSession::join: Cannot join ended session"
        );

        (
            uint8 resonance,
            uint8 health,
            uint8 attack,
            uint8 criticalHit
        ) = seekerContract.getCombatData(seekerID);

        SlotConfig memory cfg = SlotConfig({
            action: action,
            tick: uint8(tick),
            resonance: resonance,
            health: health,
            attack: attack,
            criticalHit: criticalHit
        });

        slots[slotID].seekerID = seekerID;
        slots[slotID].hash = hasher.poseidon(
            [slots[slotID].hash, packSlotConfig(cfg)]
        );

        emit SlotUpdated(slotID, cfg);
    }

    // -- SLOT GETTERS

    function getSeekerSlotID(uint seekerID) public view returns (uint8, bool) {
        for (uint8 i = 0; i < SEEKER_CAP; i++) {
            if (slots[i].seekerID == seekerID) {
                return (i, true);
            }
        }

        return (0, false);
    }

    function getFreeSlotID() public view returns (uint8, bool) {
        for (uint8 i = 0; i < SEEKER_CAP; i++) {
            if (slots[i].seekerID == 0) {
                return (i, true);
            }
        }

        return (0, false);
    }

    function getSlots() public view returns (Slot[SEEKER_CAP] memory) {
        return slots;
    }

    // function getSlotYieldsWithOffChainStorage(uint t, SlotConfig[][] calldata cfgs) public view returns (uint[SEEKER_CAP] memory yields) {0
    //     uint s;
    //     uint i;
    //     uint r;
    //     uint y;
    //     uint[SEEKER_CAP] memory actionIndex;
    //     uint rewardSupply = session.rewardSupply;
    //     uint[SEEKER_CAP] memory health;
    //     // apply state transition calculation for each tick
    //     for (i=0; i<NUM_TICKS; i++) {
    //         r = rollD100(i);
    //         for (s=0; s<SEEKER_CAP; s++) {
    //             // pick correct action state for t
    //             while (actionIndex[s]+1 < cfgs[s].length && i < cfgs[s][actionIndex[s]].tick && i >= cfgs[s][actionIndex[s]+1].tick) {
    //                 actionIndex[s] += 1;
    //             }
    //             // tile does "damage" to seeker
    //             health[s] = health[s] + 1; // TODO this is shared between all seekers
    //             // calc yield for this tick for this seeker
    //             y = cfgs[s][actionIndex[s]].hrv;
    //             // calc yield bonus (if applicable)
    //             if (r > 90) {
    //                 y = cfgs[s][actionIndex[s]].yldb;
    //             }
    //             // ensure yield is not larger than remaining supply
    //             y = min(rewardSupply, y);
    //             // decrement y from the available session resources
    //             rewardSupply -= y;
    //             // yield is a rolling total, so add to previous tick
    //             yields[s] += y;
    //         }
    //         // stop processing after t
    //         if (i == t) {
    //             break;
    //         }
    //     }

    //     return yields;
    // }

    // -- PACK / UNPACK

    function packSlotConfig(SlotConfig memory config) public pure returns (uint256) {
        return
            (uint256(config.action)) |
            (uint256(config.tick) << 8) |
            (uint256(config.resonance) << 16) |
            (uint256(config.health) << 24) |
            (uint256(config.attack) << 32) |
            (uint256(config.criticalHit) << 40);
    }

    function unpackSlotConfig(
        uint256 configPacked
    ) public pure returns (SlotConfig memory config) {
        return
            SlotConfig({
                action: CombatAction(configPacked & 8),
                tick: uint8((configPacked >> 8) & 8),
                resonance: uint8((configPacked >> 16) & 8),
                health: uint8((configPacked >> 24) & 8),
                attack: uint8((configPacked >> 32) & 8),
                criticalHit: uint8((configPacked >> 40) & 8)
            });
    }
}
