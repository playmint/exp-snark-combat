// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
pragma abicoder v2;

import "./Alignment.sol";
import "./Seeker.sol";

import "forge-std/console2.sol"; // FIXME: remove

uint constant NUM_SEEKERS = 3; // CONFIG:NUM_SEEKERS
uint constant NUM_TICKS = 100; // CONFIG:NUM_TICKS

uint constant VERIFIER_NOHASH_INPUTS = (NUM_SEEKERS)+(4*NUM_SEEKERS*NUM_TICKS)+1;
uint constant VERIFIER_WITHHASH_INPUTS = (NUM_SEEKERS*2)+1;

interface IPoseidonHasher {
    function poseidon(uint256[2] memory inp) external pure returns (uint256 out);
}

interface IVerifierNoHash {
    function verifyProof(
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[VERIFIER_NOHASH_INPUTS] memory input
    ) external view returns (bool r);
}

interface IVerifierWithHash {
    function verifyProof(
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[VERIFIER_WITHHASH_INPUTS] memory input
    ) external view returns (bool r);
}

enum ActionKind {
    JOIN,
    LEAVE
}

struct OffChainSlot {
    uint32 seekerID;
    uint16 claimed;
    uint256 hash;
}

struct OnChainSlot {
    uint32 seekerID;
    uint16 claimed;
}

struct SessionConfig {
// | ATTRIBUTE | DESCRIPTION |
// | --- | --- |
// | SEEKER LEVEL REQ | Determines the minimum Seeker level required for a Seeker to Harvest the tile. |
// | SEEKER CAP | The maximum number of Seekers allowed per session |
// | ENDURANCE REQ | Determines the minimum Endurance attribute required for a Seeker to Harvest the tile. |
// | TYPE  | Determines the loot pool used for reward distribution. |
// | AFFINITY  | Determines the corruption rating of the tile. |
// |  |  |
// | SESSION SUPPLY | Determines the maximum number of allocated resources to be distributed as rewards |
// | SESSION BONUS SUPPLY | Determines the value of rewards distributed if a session is fully depleted |
// | SESSION DURATION | Determines the duration of the Harvesting session. |
// | REGEN DURATION | Determines the duration it takes the tile to regenerate once the Harvesting session has ended. |
// | MAX RESPAWN | The maximum number of times a tile can respawn |
// | RESPAWN SUPPLY DECAY | The percentage reduction of resource reward value on respawn (based on initial session value) |
// | MIN DECAYED SUPPLY | The minimum number of resources a tile can be allocated as rewards on respawn  |
    uint8 seekerCap;
    uint8 enduranceReq;
    uint8 affinity;
    uint8 rewardSupply;
    uint8 bonusSupply;
    uint32 startTick;
}

struct SlotConfig {
    ActionKind action;
    uint8 tick;
    uint8 hrv;
    uint8 yldb;
    uint8 end;
}

struct ClaimProof {
    uint[2] pi_a;
    uint[2][2] pi_b;
    uint[2] pi_c;
}

struct Claim {
    uint8 slot;
    uint8 tick;
    uint16[NUM_SEEKERS] yields;
}

contract Session {

    event SlotUpdated (
        uint8 slotID,
        SlotConfig cfg
    );

    Seeker seekerContract;
    IVerifierWithHash verifierWithHashContract;
    IVerifierNoHash verifierNoHashContract;
    IPoseidonHasher hasher;

    // current battle config
    SessionConfig public session;
    OffChainSlot[NUM_SEEKERS] public offChainSlots; // used by joinSessionWith[Event|Tx]Storage


    OnChainSlot[NUM_SEEKERS] public onChainSlots; // used by joinSessionWith[Event|Tx]Storage
    SlotConfig[][] public onChainConfigs; // used by joinSessionWithStateStorage

    constructor(
        address _seekerContractAddr,
        address _verifierWithHashContractAddr,
        address _verifierNoHashContractAddr,
        address _hasherContractAddr
    ) {
        seekerContract = Seeker(_seekerContractAddr);
        verifierWithHashContract = IVerifierWithHash(_verifierWithHashContractAddr);
        verifierNoHashContract = IVerifierNoHash(_verifierNoHashContractAddr);
        hasher = IPoseidonHasher(_hasherContractAddr);
        // init session
        session.rewardSupply = 255;
    }

    // FIXME: just hardcoding some "random" numbers for now
    uint[NUM_TICKS] rand = [75,98,98,35,97,20,21,34,22,98,64,2,63,11,3,80,86,12,50,99,16,78,19,88,72,7,86,28,41,72,10,86,40,23,32,84,55,7,82,9,31,58,17,92,26,61,39,51,70,54,90,3,41,32,53,28,10,63,98,12,2,47,59,21,9,4,19,11,99,11,25,16,24,37,27,10,4,7,70,66,24,41,7,15,28,29,58,55,64,84,34,47,31,70,60,30,88,55,47,51]; // CONFIG:RAND
    function rollD100(uint t) public view returns (uint) {
        return rand[t];
    }

    function getOnChainConfigs() public view returns (SlotConfig[][] memory) {
        return onChainConfigs;
    }

    function verifyProofWithOffChainStorage(Claim calldata claim, ClaimProof memory proof) public view returns (bool) {
        uint[VERIFIER_WITHHASH_INPUTS] memory input;
        uint i = 0;
        uint s;
        for (s=0; s<NUM_SEEKERS; s++) {
            input[i] = claim.yields[s];
            i++;
        }
        for (s=0; s<NUM_SEEKERS; s++) {
            input[i] = offChainSlots[s].hash;
            i++;
        }
        input[i] = claim.tick;
        i++;
        uint rewardSupply = session.rewardSupply; // TODO: this should be an input signal
        return verifierWithHashContract.verifyProof(proof.pi_a, proof.pi_b, proof.pi_c, input);
    }

    uint constant OFFSET_HRV = NUM_SEEKERS;
    uint constant OFFSET_YLB = OFFSET_HRV + (NUM_SEEKERS*NUM_TICKS);
    uint constant OFFSET_END = OFFSET_YLB + (NUM_SEEKERS*NUM_TICKS);
    uint constant OFFSET_ACT = OFFSET_END + (NUM_SEEKERS*NUM_TICKS);
    uint constant OFFSET_TICK = OFFSET_ACT + (NUM_SEEKERS*NUM_TICKS);
    function verifyProofWithOnChainStorage(Claim calldata claim, ClaimProof memory proof) public view returns (bool) {
        uint[VERIFIER_NOHASH_INPUTS] memory input;
        uint t;
        uint s;
        // outputs (yields)
        for (s=0; s<NUM_SEEKERS; s++) {
            input[s] = claim.yields[s];
        }
        // public inputs (HRV,YLB,END,ACT)
        uint i = 0;
        uint[NUM_SEEKERS] memory actionIndex;
        for (t=0; t<NUM_TICKS; t++) {
            for (s=0; s<NUM_SEEKERS; s++) {
                // skip if action not valid yet
                if (t<onChainConfigs[s][actionIndex[s]].tick) {
                    i++;
                    continue;
                }
                // pick correct action state for t
                while (actionIndex[s]+1 < onChainConfigs[s].length && t < onChainConfigs[s][actionIndex[s]].tick && t >= onChainConfigs[s][actionIndex[s]+1].tick) {
                    actionIndex[s] += 1;
                }
                input[OFFSET_HRV+i] = onChainConfigs[s][actionIndex[s]].hrv;
                input[OFFSET_YLB+i] = onChainConfigs[s][actionIndex[s]].yldb;
                input[OFFSET_END+i] = onChainConfigs[s][actionIndex[s]].end;
                input[OFFSET_ACT+i] = uint(onChainConfigs[s][actionIndex[s]].action);
                console2.log(OFFSET_HRV+i, input[OFFSET_HRV+i]);
                console2.log(OFFSET_YLB+i, input[OFFSET_YLB+i]);
                console2.log(OFFSET_END+i, input[OFFSET_END+i]);
                console2.log(OFFSET_ACT+i, input[OFFSET_ACT+i]);
                i++;
            }
        }
        input[OFFSET_TICK] = claim.tick;
        return verifierNoHashContract.verifyProof(proof.pi_a, proof.pi_b, proof.pi_c, input);
    }

    function getSlotYieldsWithOnChainStorage(uint t) public view returns (uint[NUM_SEEKERS] memory yields) {
        uint s;
        uint i;
        uint r;
        uint y;
        uint[NUM_SEEKERS] memory actionIndex;
        uint rewardSupply = session.rewardSupply;
        uint[NUM_SEEKERS] memory health;
        // apply state transition calculation for each tick
        for (i=0; i<NUM_TICKS; i++) {
            r = rollD100(i);
            for (s=0; s<NUM_SEEKERS; s++) {
                // pick correct action state for t
                while (actionIndex[s]+1 < onChainConfigs[s].length && i < onChainConfigs[s][actionIndex[s]].tick && i >= onChainConfigs[s][actionIndex[s]+1].tick) {
                    actionIndex[s] += 1;
                }
                // tile does "damage" to seeker
                health[s] = health[s] + 1; // TODO this is shared between all seekers
                // calc yield for this tick for this seeker
                y = onChainConfigs[s][actionIndex[s]].hrv;
                // calc yield bonus (if applicable)
                if (r > 90) {
                    y = onChainConfigs[s][actionIndex[s]].yldb;
                }
                // ensure yield is not larger than remaining supply
                y = min(rewardSupply, y);
                // decrement y from the available session resources
                rewardSupply -= y;
                // yield is a rolling total, so add to previous tick
                yields[s] += y;
            }
            // stop processing after t
            if (i == t) {
                break;
            }
        }

        return yields;
    }

    function getSlotYieldsWithOffChainStorage(uint t, SlotConfig[][] calldata cfgs) public view returns (uint[NUM_SEEKERS] memory yields) {
        uint s;
        uint i;
        uint r;
        uint y;
        uint[NUM_SEEKERS] memory actionIndex;
        uint rewardSupply = session.rewardSupply;
        uint[NUM_SEEKERS] memory health;
        // apply state transition calculation for each tick
        for (i=0; i<NUM_TICKS; i++) {
            r = rollD100(i);
            for (s=0; s<NUM_SEEKERS; s++) {
                // pick correct action state for t
                while (actionIndex[s]+1 < cfgs[s].length && i < cfgs[s][actionIndex[s]].tick && i >= cfgs[s][actionIndex[s]+1].tick) {
                    actionIndex[s] += 1;
                }
                // tile does "damage" to seeker
                health[s] = health[s] + 1; // TODO this is shared between all seekers
                // calc yield for this tick for this seeker
                y = cfgs[s][actionIndex[s]].hrv;
                // calc yield bonus (if applicable)
                if (r > 90) {
                    y = cfgs[s][actionIndex[s]].yldb;
                }
                // ensure yield is not larger than remaining supply
                y = min(rewardSupply, y);
                // decrement y from the available session resources
                rewardSupply -= y;
                // yield is a rolling total, so add to previous tick
                yields[s] += y;
            }
            // stop processing after t
            if (i == t) {
                break;
            }
        }

        return yields;
    }

    function verifyStateOnChain(Claim calldata claim, SlotConfig[][] calldata cfgs) public view returns (bool) {
        uint h;
        // calc the yields for the requested tick and cfg
        uint[NUM_SEEKERS] memory yields = getSlotYieldsWithOffChainStorage(claim.tick, cfgs);
        // verify the given slot configs match the commited hashes
        for (uint s=0; s<NUM_SEEKERS; s++) {
            h = 0;
            for (uint i=0; i<cfgs[s].length; i++) {
                h = hasher.poseidon([
                    h,
                    packSlotConfig(cfgs[s][i])
                ]);
            }
            require(h == offChainSlots[s].hash, 'unverified action data');
            // verify that the supplied claim yields match the calculated yields
            require(claim.yields[s] == yields[s], 'unverified yields');
        }
        // ok
        return true;
    }

    function verifyStateOnChain(Claim calldata claim) public view returns (bool) {
        // calc the yields for the requested tick and cfg
        uint[NUM_SEEKERS] memory yields = getSlotYieldsWithOnChainStorage(claim.tick);
        // verify that the supplied claim yields match the calculated yields
        for (uint s=0; s<NUM_SEEKERS; s++) {
            require(claim.yields[s] == yields[s], 'unverified yields');
        }
        // ok
        return true;
    }

    function claimWithOnChainCalcOffChainStorage(Claim calldata claim, SlotConfig[][] calldata cfgs) public {
        // validate claim
        require(verifyGenericClaims(claim.slot, claim.tick), 'invalid claim args');
        require(verifyStateOnChain(claim, cfgs), 'invalid claim state');
        // claim
        offChainSlots[claim.slot].claimed += claimableYield(claim.yields[claim.slot], offChainSlots[claim.slot].claimed);
    }

    function claimWithOffChainCalcOffChainStorage(Claim calldata claim, ClaimProof memory proof) public {
        // validate claim
        require(verifyGenericClaims(claim.slot, claim.tick), 'invalid claim args');
        require(verifyProofWithOffChainStorage(claim, proof), "proof failed to verify");
        // claim
        offChainSlots[claim.slot].claimed += claimableYield(claim.yields[claim.slot], offChainSlots[claim.slot].claimed);
    }

    function claimWithOffChainCalcOnChainStorage(Claim calldata claim, ClaimProof memory proof) public {
        // validate claim
        require(verifyGenericClaims(claim.slot, claim.tick), 'invalid claim args');
        require(verifyProofWithOnChainStorage(claim, proof), "proof failed to verify");
        //claim
        onChainSlots[claim.slot].claimed += claimableYield(claim.yields[claim.slot], onChainSlots[claim.slot].claimed);
    }

    function claimWithOnChainCalcOnChainStorage(Claim calldata claim) public {
        // validate claim
        require(verifyGenericClaims(claim.slot, claim.tick), 'invalid claim args');
        require(verifyStateOnChain(claim), 'invalid claim state');
        // claim
        onChainSlots[claim.slot].claimed += claimableYield(claim.yields[claim.slot], onChainSlots[claim.slot].claimed);
    }

    // verifyGenericClaims are things that need to be validated regardless if on or off chain
    function verifyGenericClaims(uint slotID, uint tick) private view returns (bool) {
        // find the seekerID from the given slotID
        uint seekerID = offChainSlots[slotID].seekerID;
        // ensure there is a seeker in the slot
        require(seekerID != 0, 'no seeker in slot');
        // ensure sender is owner of seeker in slot
        require(seekerContract.ownerOf(seekerID) == tx.origin, 'not owner of seeker in slot');
        // check the given tick is in the past
        require(tick <= block.number - session.startTick, 'cannot claim from the future');
        // ok
        return true;
    }

    // claimYield mints the <yield> of resource or whatever is left
    function claimableYield(uint16 yield, uint16 claimed) private pure returns (uint16 claimable) {
        // calc the claimable yield, since we may have already claimed some
        claimable = yield;
        if (yield > 0 && yield > claimed) {
            claimable = yield - claimed;
        }
    }

    function resetSessionWithOffChainStorage(
        uint8 aff
    ) public {
        session.affinity = aff;
        session.startTick = uint32(block.number);
        for (uint i=0; i<offChainSlots.length; i++) {
            offChainSlots[i] = OffChainSlot(0,0,0);
        }
    }

    function resetSessionWithOnChainStorage(
        uint8 aff
    ) public {
        session.affinity = aff;
        session.startTick = uint32(block.number);
        for (uint i=0; i<onChainSlots.length; i++) {
            onChainSlots[i] = OnChainSlot(0,0);
        }
    }

    function modSessionWithOffChainStorage(
        uint8 seekerID
    ) public {
        // grab if seeker in a slot
        (uint slotID, bool ok) = getSeekerSlotIDOffChainStorage(seekerID);
        if (!ok) {
            require(ok, "seeker not in slot");
        }
        // do generic action validation
        SlotConfig memory cfg = _joinSession(seekerID); // same as join for this test, IRL would be something else
        // update the hash
        offChainSlots[slotID].hash = hasher.poseidon([
            offChainSlots[slotID].hash,
            packSlotConfig(cfg)
        ]);
        // log the action data
        emit SlotUpdated(uint8(slotID), cfg);
    }

    function modSessionWithOnChainStorage(
        uint8 seekerID
    ) public {
        // grab if seeker in a slot
        (uint slotID, bool ok) = getSeekerSlotIDOnChainStorage(seekerID);
        if (!ok) {
            require(ok, "seeker not in slot");
        }
        // do generic action validation
        SlotConfig memory cfg = _joinSession(seekerID);
        // update on-chain storage
        onChainConfigs[slotID].push(cfg);
    }

    function joinSessionWithOffChainStorage(
        uint8 seekerID
    ) public {
        // grab if seeker in a slot
        (uint slotID, bool ok) = getSeekerSlotIDOffChainStorage(seekerID);
        if (!ok) {
            (slotID, ok) = getFreeSlotIDOffChainStorage();
            require(ok, "session is full");
        }
        // do generic session join validation
        SlotConfig memory cfg = _joinSession(seekerID);
        // update the slot owner in off-chain slots
        offChainSlots[slotID].seekerID = seekerID;
        // update the hash
        offChainSlots[slotID].hash = hasher.poseidon([
            offChainSlots[slotID].hash,
            packSlotConfig(cfg)
        ]);
        // log the action data
        emit SlotUpdated(uint8(slotID), cfg);
    }

    function joinSessionWithOnChainStorage(
        uint8 seekerID
    ) public {
        // grab if seeker in a slot
        (uint slotID, bool ok) = getSeekerSlotIDOnChainStorage(seekerID);
        if (!ok) {
            (slotID, ok) = getFreeSlotIDOnChainStorage();
            require(ok, "session is full");
        }
        // do generic session join validation
        SlotConfig memory cfg = _joinSession(seekerID);
        // update on-chain storage
        onChainSlots[slotID].seekerID = seekerID;
        SlotConfig[] storage slot = onChainConfigs.push();
        slot.push(cfg);
    }

    function _joinSession(
        uint8 seekerID
    ) private view returns (SlotConfig memory) {
        // ensure sender owns seeker
        require(seekerContract.ownerOf(seekerID) == tx.origin, 'not your seeker');
        // get the stats values
        uint8[8] memory attrs = seekerContract.getAttrs(seekerID);
        // calc affinity bonus to hrv
        // TODO: is corruption the right stat here?
        uint8 hrv = (attrs[2]+8) + uint8(9 - (
            max(attrs[7], session.affinity)
            -
            min(attrs[7], session.affinity)
        ));
        require(block.number - session.startTick <= NUM_TICKS, 'session ended');
        // build slot config
        return SlotConfig({
            action: ActionKind.JOIN,
            tick: uint8(block.number - session.startTick),
            hrv: hrv, // TODO: update seeker stats
            yldb: 5, // TODO: what modifies this?
            end: 100
        });
    }

    // getSlotID returns the slot index for the given seeker ID or -1 is not
    function getSeekerSlotIDOffChainStorage(uint seekerID) public view returns (uint, bool) {
        for (uint i=0; i<NUM_SEEKERS; i++) {
            if (offChainSlots[i].seekerID == seekerID) {
                return (i, true);
            }
        }
        return (0, false);
    }

    // getFreeSlotID returns an available slot or -1 if full
    function getFreeSlotIDOffChainStorage() public view returns (uint, bool) {
        for (uint i=0; i<NUM_SEEKERS; i++) {
            if (offChainSlots[i].seekerID == 0) {
                return (i, true);
            }
        }
        return (0, false);
    }

    // getSlotID returns the slot index for the given seeker ID or -1 is not
    function getSeekerSlotIDOnChainStorage(uint seekerID) public view returns (uint, bool) {
        for (uint i=0; i<NUM_SEEKERS; i++) {
            if (onChainSlots[i].seekerID == seekerID) {
                return (i, true);
            }
        }
        return (0, false);
    }

    // getFreeSlotID returns an available slot or -1 if full
    function getFreeSlotIDOnChainStorage() public view returns (uint, bool) {
        for (uint i=0; i<NUM_SEEKERS; i++) {
            if (onChainSlots[i].seekerID == 0) {
                return (i, true);
            }
        }
        return (0, false);
    }

    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) public pure returns (uint256) {
        return a > b ? a : b;
    }

    function packSlotConfig(SlotConfig memory cfg) private pure returns(uint256 packed) {
        return 0
        | (uint256(cfg.action) << 8)
        | (uint256(cfg.tick) << 21)
        | (uint256(cfg.hrv) << 34)
        | (uint256(cfg.yldb) << 47)
        | (uint256(cfg.end) << 60);
        // | (uint256(0) << 73)
        // | (uint256(0) << 86)
        // | (uint256(0) << 99);
    }

    function unpackSlotConfig(uint256 packed) private pure returns(SlotConfig memory cfg) {
        cfg.action = ActionKind(uint8((packed >> 8) & 0x1fff));
        cfg.tick = uint8((packed >> 21) & 0x1fff);
        cfg.hrv = uint8((packed >> 34) & 0x1fff);
        cfg.yldb = uint8((packed >> 47) & 0x1fff);
        cfg.end = uint8((packed >> 60) & 0x1fff);
        // attrs[5] = uint8((packed >> 73) & 0x1fff);
        // attrs[6] = uint8((packed >> 86) & 0x1fff);
        // attrs[7] = uint8((packed >> 99) & 0x1fff);
    }

}
