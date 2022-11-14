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

    function join(uint seekerID) public onlyOwner {
        (uint8 slotID, bool ok) = getSeekerSlotID(seekerID);
        if (!ok) {
            (slotID, ok) = getFreeSlotID();
            require(ok, "CombatSession::join: No slots available");
        }

        updateSlot(slotID, seekerID, CombatAction.JOIN);
    }

    function leave(uint seekerID) public onlyOwner {
        (uint8 slotID, bool ok) = getSeekerSlotID(seekerID);

        require(ok, "CombatSession::leave: Seeker not found");

        updateSlot(slotID, seekerID, CombatAction.LEAVE);
    }

    function updateSlot(
        uint8 slotID,
        uint seekerID,
        CombatAction action
    ) private {
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

    // --  YIELD / CLAIM

    function getSlotYieldsWithOffChainStorage(
        uint terminalTick,
        SlotConfig[][] calldata cfgs
    ) public view returns (uint[SEEKER_CAP] memory yields) {
        uint t;
        uint s;
        uint r;
        uint y;
        uint a;

        CombatTileData memory _tileData = tileData; // Aliased to minimise storage reads
        uint rewardSupply = _tileData.sessionSupply; // TODO: Decay
        uint enemyHealth = _tileData.health;
        uint[SEEKER_CAP] memory enemyDamage;

        uint[SEEKER_CAP] memory actionIndex;
        uint[SEEKER_CAP] memory seekerDamage;

        // apply state transition calculation for each tick
        for (t = 0; t < NUM_TICKS; t++) {
            r = rollD100(t); // TODO: Roll for each seeker not each tick
            for (s = 0; s < SEEKER_CAP; s++) {
                // stop process if enemy dead
                if (enemyHealth == 0) {
                    break;
                }

                // Slot empty so skip
                if (cfgs[s].length == 0) {
                    break;
                }

                // No action occurring on this tick
                if (t < cfgs[s][actionIndex[s]].tick) {
                    continue;
                }

                // pick correct action state for t
                while (
                    actionIndex[s] + 1 < cfgs[s].length &&
                    t >= cfgs[s][actionIndex[s] + 1].tick
                ) {
                    actionIndex[s] += 1;
                }

                if (cfgs[s][actionIndex[s]].action == CombatAction.LEAVE) {
                    continue;
                }

                // tile does "damage" to seeker
                if (seekerDamage[s] < cfgs[s][actionIndex[s]].health) {
                    seekerDamage[s] += _tileData.attack;
                }

                // Seeker dead
                if (seekerDamage[s] >= cfgs[s][actionIndex[s]].health) {
                    continue;
                }

                // -- Calc seeker attack

                a = cfgs[s][actionIndex[s]].attack;

                // Attack bonus on critical hit
                if (r < cfgs[s][actionIndex[s]].criticalHit) {
                    a += a;
                }
                // ensure attack is not larger than remaining enemy health
                a = min(enemyHealth, a);

                enemyHealth -= a;

                // Keep track of how much damage each seeker dealth as this is used to work out yield
                enemyDamage[s] += a;
            }

            // stop processing after t
            if (t == terminalTick) {
                break;
            }

            // stop process if enemy dead
            if (enemyHealth == 0) {
                break;
            }
        }

        // Calc yield and count participants
        uint numParticipants;
        for (s = 0; s < SEEKER_CAP; s++) {
            if (enemyDamage[s] > 0) {
                numParticipants++;
                yields[s] = ((enemyDamage[s] * 100) / _tileData.health * rewardSupply) / 100;
            }
        }

        // If enemy defeated then award bonus
        if (enemyHealth == 0) {
            // Would this be a problem when converting to circuit?
            for (s = 0; s < numParticipants; s++) {
                yields[s] += _tileData.bonusSupply / numParticipants; // TODO: Decayed bonus?
            }
        }

        return yields;
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

    // -- PACK / UNPACK

    function packSlotConfig(
        SlotConfig memory config
    ) public pure returns (uint256) {
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

    // -- MATH

    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) public pure returns (uint256) {
        return a > b ? a : b;
    }

    // -- RND

    // FIXME: just hardcoding some "random" numbers for now
    uint[NUM_TICKS] rand = [75,98,98,35,97,20,21,34,22,98,64,2,63,11,3,80,86,12,50,99,16,78,19,88,72,7,86,28,41,72,10,86,40,23,32,84,55,7,82,9,31,58,17,92,26,61,39,51,70,54,90,3,41,32,53,28,10,63,98,12,2,47,59,21,9,4,19,11,99,11,25,16,24,37,27,10,4,7,70,66,24,41,7,15,28,29,58,55,64,84,34,47,31,70,60,30,88,55,47,51]; // CONFIG:RAND
    function rollD100(uint t) public view returns (uint) {
        return rand[t];
    }

}
