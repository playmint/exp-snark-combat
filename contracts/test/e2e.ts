import { expect } from 'chai';
import { createDeployment, deployContracts } from "../scripts/deployContracts";
import { CombatManager, CombatSession, Mod, Seeker } from "../typechain-types";
import path from "path";
import fs from "fs";
import chai from "chai";
import { ethers } from 'hardhat';
import { BigNumber, Contract } from "ethers";
import hre from "hardhat";
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { TransactionResponse } from '@ethersproject/abstract-provider';
import * as snarkjs from "snarkjs";
import * as circomlib from "circomlibjs";
import { json } from 'hardhat/internal/core/params/argumentTypes';

const deployment = createDeployment(hre);
const provider = hre.ethers.provider;

let signer:SignerWithAddress;
let seekerContract:Seeker;
let modContract:Mod;
let combatManager:CombatManager;

function env(key:string):string {
    const v = process.env[key];
    if (!v) {
        throw new Error(`env ${key} must be set`);
    }
    return v;
}
const NUM_SEEKERS = parseInt(env('NUM_SEEKERS'));
const NUM_TICKS = parseInt(env('NUM_TICKS'));
// const NUM_ACTIONS = parseInt(env('NUM_ACTIONS'));
const seekerGeneration = 1;

interface Prover {
    wasm: string;
    key: string;
    withHashes: boolean;
}

// const PROVE_ON_CHAIN_INPUTS:Prover = {
//     wasm: env('NOHASH_WASM_PATH'),
//     key: env('NOHASH_KEY_PATH'),
//     withHashes: false,
// };
// const PROVE_OFF_CHAIN_INPUTS:Prover = {
//     wasm: env('WITHHASH_WASM_PATH'),
//     key: env('WITHHASH_KEY_PATH'),
//     withHashes: true,
// };

enum GameObjectAttr {
    resonance,     // 0
    health,        // 1
    attack,        // 2
    criticalHit,   // 3
    agility,       // 4
    scout,         // 5
    capacity,      // 6
    endurance,     // 7
    harvest,       // 8
    yieldBonus,    // 9
    assemblySpeed, // 10
    modBonus       // 11
}

enum CombatAction {
    JOIN,
    LEAVE,
    EQUIP
}

interface Position {
    x: number;
    y: number;
}

interface Slot {
    seekerID: BigNumber;
    claimed: number;
    hash: BigNumber;
    configs: SlotConfig[];
}

interface SlotConfig {
    action: number;
    tick: number;
    resonance: number;
    health: number;
    attack: number;
    criticalHit: number;
}

interface SessionState {
    startBlock: number,
    slots: Slot[],
}

// interface Claim {
//     slot: number;
//     tick: number;
//     yields: any;
// }
// interface CombatState {
//     sessionArmour: number;
//     sessionHealth: number;
//     seekerArmour: number;
//     seekerHealth: number;
//     slot: number;
//     tick: number;
//     pi_a: number[];
//     pi_b: number[][];
//     pi_c: number[];
// };


describe('E2E', async function () {

    this.timeout(1000000000);

    before(async () => {
        // keep the signer addr
        [signer] = await ethers.getSigners();
        // wait for contract deployment to complete
        ({ seekerContract, modContract, combatManager } = await deployContracts(deployment));
        // mint n seekers
        for (let i=0; i<NUM_SEEKERS; i++) {
            await seekerContract.mint(
                signer.address,
                seekerGeneration,
                [
                    i, // resonance
                    100, // health
                    1, // attack
                    i==0? 0 : 0, // criticalHit

                    2, // agility
                    2, // scout
                    2, // capacity
                    2, // endurance
                    2, // harvest
                    2, // yieldBonus
                    2, // craftingSpeed
                    2, // modBonus
                ],
            ).then(tx => tx.wait());
        }

        await modContract.mint(
            signer.address, 
            GameObjectAttr.attack,
            10,
        ).then(tx => tx.wait());
        await modContract.mint(
            signer.address, 
            GameObjectAttr.attack,
            10,
        ).then(tx => tx.wait());
        await modContract.mint(
            signer.address, 
            GameObjectAttr.attack,
            100,
        ).then(tx => tx.wait());

        // manual mining mode
        // await ethers.provider.send("evm_setAutomine", [false]);
    });


    const tick = NUM_TICKS; // always prove this number of ticks
    const slot = 0; // always prove this slot
    const pos = {x: 1024, y: 1024};


    let sessionCorruption = 50;
    let sessionStartBlock:number;

    async function mine(txs:any[]): Promise<any> {
        await ethers.provider.send("evm_mine", []);
        while(true) {
            const pendingBlock = await ethers.provider.send("eth_getBlockByNumber", ["pending", true]);
            if (pendingBlock.transactions.length==0) {
                break;
            }
            console.log(`waiting for ${pendingBlock.transactions.length} to mine`);
            await ethers.provider.send("evm_mine", []);
        }
        if (txs.length>0) {
            return Promise.all(txs.map(tx => tx.wait()));
        } else {
            return;
        }
    }

    it("Should return seeker data for last ID", async () => {
        const seekerData = await seekerContract.getData(NUM_SEEKERS);
        // console.log(`seekerData:`, seekerData);
        expect(seekerData.id).to.not.eq(0);
    });
    
    it("Should return mod data for ID 1", async () => {
        const modData = await modContract.getData(1);
        // console.log(`modData:`, modData);
        expect(modData.id).to.not.eq(0);
    });

    // -- MODS

    it("Should be able to equip 2 mods ", async () => {
        // Equip mods 1 and 2
        await modContract.equip(1, 1).then(tx => tx.wait());
        await modContract.equip(1, 2).then(tx => tx.wait());
        
        const equippedMods = await modContract.getSeekerMods(1);
        expect(equippedMods.length).to.eq(2);
        expect(equippedMods[0]).to.eq(1);

        // Cannot re-equip same mod
        let couldReEquip = false;
        try {
            await modContract.equip(1, 1).then(tx => tx.wait());
            couldReEquip = true;
        } catch {}

        expect(couldReEquip, "Shouldn't be able to re-equip same mod").to.eq(false);
    })

    it("Unquipping the first mod should leave the second mod in slot 0", async () => {
        await modContract.unequip(1, 1).then(tx => tx.wait());
        const equippedMods = await modContract.getSeekerMods(1);
        expect(equippedMods.length).to.eq(1);
        expect(equippedMods[0], "Expected equipped mod to be mod equipped second").to.eq(2);
    })

    it("Should return modded stats for the seeker", async() => {
        const baseStats = await seekerContract.getAttrs(1);
        const moddedStats = await modContract.getModdedSeekerAttrs(1);

        // console.log("baseStats:", baseStats);
        // console.log("moddedStats:", moddedStats);

        const attackIndex = 2;
        expect(moddedStats[attackIndex]).to.be.gt(baseStats[attackIndex]);

        await modContract.unequip(1, 2).then(tx => tx.wait());
    })

    // -- end of MODS -- //

    it("Should instantiate and join a session", async() => {
        // manual mining mode
        await ethers.provider.send("evm_setAutomine", [false]);

        const txs: any = [];
        txs.push(await combatManager.join(pos, 1));
        txs.push(await combatManager.join(pos, 2));
        txs.push(await combatManager.join(pos, 3));

        await mine(txs);

        const state = await getSessionState(pos);

        // console.log(`state:`, state.slots[0], state.slots[1], state.slots[2]);
        console.log(`starting ticks:`, state.slots[0].configs[0].tick, state.slots[1].configs[0].tick, state.slots[2].configs[0].tick);

        expect(state.slots[1].configs[0].tick, "Expected last two joiners to join on the same tick").to.eq(state.slots[2].configs[0].tick)
    })

    it("Seeker that leaves before the others should get a lower yield", async() => {
       
        for (var i = 0; i < 10; i++) {
            await ethers.provider.send("evm_mine", []);
        }

        // Leave
        await mine(
            [await combatManager.leave(pos, 3)]
        );

        // Get session
        const {
            session,
            startBlock
        } = await getSession(pos);

        const state = await getSessionState(pos, startBlock);

        // console.log(`state:`, state.slots[0], state.slots[1], state.slots[2]);

        const configs = state.slots.map(slot => slot.configs);

        const yields = await session.getSlotYields(NUM_TICKS, configs);
        // console.log(`yield:`, yields);
        
    });

    it("Equipping mid battle should increase yield", async() => {
        // Get session
        const {
            session,
            startBlock,
            currentTick
        } = await getSession(pos);
        
        // State before equipping mod
        const stateBefore = await getSessionState(pos, startBlock);
        const configsBefore = stateBefore.slots.map(slot => slot.configs);
        const yieldsBefore = await session.getSlotYields(NUM_TICKS, configsBefore);
        // console.log(`yield before:`, yieldsBefore);

        // Mine to half way through battle
        const halfTime = Math.floor(NUM_TICKS / 2);

        for (var i = 0; i < (halfTime - currentTick); i++) {
            await ethers.provider.send("evm_mine", []);
        }

        // Equip mod (Equipped via combat manager so that event is sent)
        await mine(
            [await combatManager.equip(pos, 2, 1)]
        );

        // State after equipping mod
        const stateAfter = await getSessionState(pos, startBlock);
        const configsAfter = stateAfter.slots.map(slot => slot.configs);
        const yieldsAfter = await session.getSlotYields(NUM_TICKS, configsAfter);
        // console.log(`yield after:`, yieldsAfter);

        expect(yieldsAfter[1], 'Expected second seeker to have a higher yield than unmodded seeker').to.be.greaterThan(yieldsAfter[0]);
    });

    it("Defeating Enemy should yield bonus", async() => {
        // Get session
        const {
            session,
            startBlock,
            currentTick
        } = await getSession(pos);
        
        // State before equipping mod
        const stateBefore = await getSessionState(pos, startBlock);
        const configsBefore = stateBefore.slots.map(slot => slot.configs);
        const yieldsBefore = await session.getSlotYields(NUM_TICKS, configsBefore);
        // console.log(`yield before:`, yieldsBefore);

        // Equip mod (Equipped via combat manager so that event is sent)
        await mine(
            [await combatManager.equip(pos, 1, 2)]
        );

        const stateAfter = await getSessionState(pos, startBlock);
        const configsAfter = stateAfter.slots.map(slot => slot.configs);
        const yieldsAfter = await session.getSlotYields(NUM_TICKS, configsAfter);
        // console.log(`yield after:`, yieldsAfter);


        expect(yieldsAfter[2], "Yield of non present seeker should be higher due to bonus").to.be.greaterThan(yieldsBefore[2]);
    });

    it("Should claim up to current tick", async() => {
        // Get session
        const {
            session,
            startBlock,
            currentTick
        } = await getSession(pos);

        // Get state
        const state = await getSessionState(pos, startBlock);
        const configs = state.slots.map(slot => slot.configs);
        const yields = await session.getSlotYields(currentTick, configs);
        console.log(`currentTick:`, currentTick);
        console.log(`yields:`, yields);

        // Claim
        const claimSlot = 0;
        const claim = {
            slot: claimSlot,
            tick: currentTick,
            yields: yields
        } as CombatSession.ClaimStruct;
        await mine(
            [await session.claimReward(claim, configs)]
        );

        const newState = await getSessionState(pos, startBlock);

        expect(newState.slots[claimSlot].claimed, "Expected claimed value to equal yield").to.eq(yields[claimSlot]);
    });

    it("Doctored yields should fail to claim", async() => {     
        // Get session
        const {
            session,
            startBlock,
            currentTick
        } = await getSession(pos);

        // Get state
        const state = await getSessionState(pos, startBlock);
        const configs = state.slots.map(slot => slot.configs);

        const yields = await session.getSlotYields(currentTick, configs);
        console.log(`currentTick:`, currentTick);
        console.log(`yields:`, yields);

        // Claim
        const claimSlot = 0;
        const claim = {
            slot: claimSlot,
            tick: currentTick,
            yields: yields
        } as CombatSession.ClaimStruct;

        // Doctored yield should fail
        claim.yields = [100, 100, 100];
        let error: Error|null = null;
        try {
            await mine(
                [await session.claimReward(claim, configs)]
            )
        } catch (e: any) {
            error = e;
        }
        expect(error).to.be.an('Error');

    });

    it("Doctored configs should fail to claim", async() => {
        // Get session
        const {
            session,
            startBlock,
            currentTick
        } = await getSession(pos);

        // Get state
        const state = await getSessionState(pos, startBlock);
        const configs = state.slots.map(slot => slot.configs);

        // Doctor the config by removing the last event from seeker 3 therefore making it so they do not leave
        const realYields = await session.getSlotYields(currentTick, configs);
        configs[2].pop();
        const fakeYields = await session.getSlotYields(currentTick, configs);
        expect(fakeYields[2]).to.be.gt(realYields[2]);

        // Claim
        const claimSlot = 0;
        const claim = {
            slot: claimSlot,
            tick: currentTick,
            yields: fakeYields
        } as CombatSession.ClaimStruct;

        // Doctored config should fail
        let error: Error|null = null;
        try {
            await mine(
                [await session.claimReward(claim, configs)]
            )
        } catch (e: any) {
            error = e;
        }
        expect(error).to.be.an('Error');
    });

    it("Seeker 1 can make another claim", async() => {       
        // Get session
        const {
            session,
            startBlock,
            currentTick
        } = await getSession(pos);

        // Get state
        const state = await getSessionState(pos, startBlock);
        const configs = state.slots.map(slot => slot.configs);
        const yields = await session.getSlotYields(currentTick, configs);

        // Claim
        const claimSlot = 0;
        const claim = {
            slot: claimSlot,
            tick: currentTick,
            yields: yields
        } as CombatSession.ClaimStruct;
        await mine(
            [await session.claimReward(claim, configs)]
        );

        const newState = await getSessionState(pos, startBlock);

        expect(newState.slots[claimSlot].claimed).to.be.gt(state.slots[claimSlot].claimed);
        expect(newState.slots[claimSlot].claimed).to.be.eq(yields[claimSlot]);

    });

    it("Seeker 2 can leave, re-join and make a claim", async() => {
        // Get session
        const {
            session,
            startBlock
        } = await getSession(pos);

        // Get state
        const stateBefore = await getSessionState(pos, startBlock);
        const configsBefore = stateBefore.slots.map(slot => slot.configs);

        // What the yield would be if seeker 2 leave and come back
        const yieldsBefore = await session.getSlotYields(NUM_TICKS, configsBefore);

        // Leave for 20 ticks
        await mine(
            [await combatManager.leave(pos, 2)]
        );
        for (var i = 0; i < 20; i++) {
            await ethers.provider.send("evm_mine", []);
        }
        
        // Rejoin
        await mine(
            [await combatManager.join(pos, 2)]
        );

        // Mine to end of session
        let currentTick = (await provider.getBlockNumber()) - startBlock;
        for (var i = 0; i < NUM_TICKS - currentTick; i++) {
            await ethers.provider.send("evm_mine", []);
        }

        currentTick = (await provider.getBlockNumber()) - startBlock;
        expect(currentTick).to.be.eq(NUM_TICKS);

        const stateAfter = await getSessionState(pos, startBlock);
        const configsAfter = stateAfter.slots.map(slot => slot.configs);
        const yieldsAfter = await session.getSlotYields(NUM_TICKS, configsAfter);

        expect(yieldsBefore[1], "Expected yields where seeker doesn't leave and rejoin the battle to be higher").to.be.gt(yieldsAfter[1]);

        // Claim
        const claimSlot = 1;
        const claim = {
            slot: claimSlot,
            tick: currentTick,
            yields: yieldsAfter
        } as CombatSession.ClaimStruct;
        await mine(
            [await session.claimReward(claim, configsAfter)]
        );

        const newState = await getSessionState(pos, startBlock);

        expect(newState.slots[claimSlot].claimed).to.be.gt(stateBefore.slots[claimSlot].claimed);
        expect(newState.slots[claimSlot].claimed).to.be.eq(yieldsAfter[claimSlot]);
    });

    it("Seeker 3 cannot rejoin the ended session", async() => {
        // Get session
        const {
            session,
            startBlock,
            currentTick
        } = await getSession(pos);
        
        expect(currentTick, "Current tick should be above the number of ticks in a session").to.be.gt(NUM_TICKS);

        // Rejoin (should error)
        let error: Error|null = null;
        try {
            await mine(
                [await combatManager.join(pos, 3)]
            )
        } catch (e: any) {
            error = e;
        }
        expect(error, "Expected seeker 3 not to be able to rejoin the ended session").to.be.an('Error');
    });

    it("Should be able to rejoin after waiting session regen period", async() => {
        // Get session
        const {
            session,
            startBlock,
        } = await getSession(pos);

        const {regenDuration} = await session.tileData();

        // Mine to next session
        for (var i = 0; i < regenDuration; i++) {
            await ethers.provider.send("evm_mine", []);
        }

        // Join
        await mine(
            [await combatManager.join(pos, 3)]
        )

        let state = await getSessionState(pos);
        expect(state.slots[0].configs.length, "Expected to have only the action for join and not include past session actions").to.eq(1);
    });

    it("Each session iteration should have diminishing returns", async() => {
        // Equip strong mod to ensure one seeker can destroy the enemy
        await mine(
            [await combatManager.equip(pos, 3, 3)]
        );

        // Get session
        const {
            session,
            startBlock,
        } = await getSession(pos);

        const {regenDuration, maxSpawn} = await session.tileData();
        const sessionIteration = await session.iteration();

        const prevState = await getSessionState(pos);
        const prevConfigs = prevState.slots.map(slot => slot.configs);
        let prevYields = await session.getSlotYields(NUM_TICKS, prevConfigs);

        let numIterations = maxSpawn;
        if (numIterations == 0) {
            numIterations = 5;
            console.warn(`WARN: maxSpawn set to 0 (infinity) so setting the iteration count to: ${numIterations}`);
        }

        for (let i = sessionIteration; i < numIterations; i++) {
            // console.log(`Mining to session: ${i + 1}`);

            // Mine to next session
            for (let j = 0; j < NUM_TICKS + regenDuration; j++) {
                await ethers.provider.send("evm_mine", []);
            }

            // Join
            await mine(
                [await combatManager.join(pos, 3)]
            )
            
            const state = await getSessionState(pos);
            const configs = state.slots.map(slot => slot.configs);
            const yields = await session.getSlotYields(NUM_TICKS, configs);

            expect(state.slots[0].configs.length, "Expected to have only the action for join and not include past session actions").to.eq(1);
            
            // console.log(`prev yield: ${prevYields[0]} new yield: ${yields[0]}`);
            expect(yields[0]).to.be.lt(prevYields[0]);

            prevYields = yields;
        }
    });

    it("If the decay is at 100% then at least minDecayedSupply expected", async() => {
        // Get session
        const {
            session,
        } = await getSession(pos);
        
        const {
            minDecayedSupply, 
            respawnSupplyDecayPerc, 
            maxSpawn, 
            regenDuration,
            bonusSupply
        } = await session.tileData();

        const exhaustedIteration = 1 + 100 / respawnSupplyDecayPerc;
        const sessionIteration = await session.iteration();

        if (maxSpawn > 0) {
            expect(maxSpawn, "maxSpawn set too low to iterate enough to fully deplete supply").to.gte(exhaustedIteration);
        }

        // Mine up to exhausted iteration
        for (let i = sessionIteration; i < exhaustedIteration; i++) {
            // console.log(`Mining to session: ${i + 1}`);
            
            // Mine to next session
            for (let j = 0; j < NUM_TICKS + regenDuration; j++) {
                await ethers.provider.send("evm_mine", []);
            }

            // Join
            await mine(
                [await combatManager.join(pos, 3)]
            )
        }

        const state = await getSessionState(pos);
        const configs = state.slots.map(slot => slot.configs);
        const yields = await session.getSlotYields(NUM_TICKS, configs);

        expect(yields[0]).to.eq(minDecayedSupply + bonusSupply);

    });

    it("Cannot join a session after maxSpawn has been reached", async() => {
        // Get session
        const {
            session,
        } = await getSession(pos);

        const {
            maxSpawn,
            regenDuration
        } = await session.tileData();

        if (maxSpawn == 0) {
            console.warn("WARN: This test is not applicable if maxSpawn is set to 0 (infinity)");
            return;
        }

        // Mine to next session (should bring to one past maxSpawn)
        for (let j = 0; j < NUM_TICKS + regenDuration; j++) {
            await ethers.provider.send("evm_mine", []);
        }

        let error: Error|null = null;
        try {
            await mine(
                [await combatManager.join(pos, 3)]
            )
        } catch (e: any) {
            error = e;
        }
        expect(error).to.be.an('Error');
    });

});

async function getSession(position: Position) {
    const sessionAddr = await combatManager.getSession(position);
    expect(sessionAddr, "Expected session contract to be instantiated").to.not.eq("0x0000000000000000000000000000000000000000");
    
    const session = await ethers.getContractAt("CombatSession", sessionAddr);
    const startBlock = (await session.startBlock()).toNumber();
    const currentTick = (await provider.getBlockNumber()) - startBlock;

    return {
        session,
        startBlock,
        currentTick
    }
}

async function getSessionState(position: Position, fromBlock: number = 0): Promise<SessionState> {
    // Get session
    const {
        session,
        startBlock
    } = await getSession(position);

    fromBlock = fromBlock > 0? fromBlock : startBlock;

    // fetch the occupied slots
    const slots = (await session.getSlots()).map( ({seekerID, claimed, hash}) => {
        return {
            seekerID,
            claimed,
            hash,
            configs: []
        } as Slot
    })

    // fetch all the Action events
    const events = await session.queryFilter(session.filters.SlotUpdated(), fromBlock, 50000);
    // group the Actions by their seeker slot
    events.forEach(({blockNumber, args}) => {
        const [
            slotID,
            config,
        ] = args;
        slots[slotID].configs.push(config);
    });

    return {
        startBlock,
        slots,
    }
}

// Creats a slot config for every tick
function explodeState(sessionState: SessionState, numTicks: number): SessionState {
    
    const slots: Slot[] = sessionState.slots.map( slot => {
        var explodedSlot = {} as Slot;
        explodedSlot.seekerID = slot.seekerID;
        explodedSlot.claimed = slot.claimed;
        explodedSlot.hash = slot.hash;

        explodedSlot.configs = Array(numTicks).fill({
            action: 0,
            tick: 0,
            resonance: 0,
            health: 0,
            attack: 0,
            criticalHit: 0
        });

        slot.configs.forEach( config => {
            explodedSlot.configs.fill(config, config.tick, numTicks);
        });

        return explodedSlot;
    });

    return {
        startBlock: sessionState.startBlock,
        slots: slots
    };
}

// async function generateInputs(cfgs:SlotConfig[][], currentTick:number, withHashes:boolean) {

//     // convert actions into expanded list of all inputs at each tick per seeker
//     const inputs = {
//         seekerHRV: Array(NUM_TICKS).fill(null).map(() => Array(NUM_SEEKERS).fill(0)),
//         seekerYLB: Array(NUM_TICKS).fill(null).map(() => Array(NUM_SEEKERS).fill(0)),
//         seekerEND: Array(NUM_TICKS).fill(null).map(() => Array(NUM_SEEKERS).fill(0)),
//         seekerACT: Array(NUM_TICKS).fill(null).map(() => Array(NUM_SEEKERS).fill(0)),
//         currentTick,
//     } as any;
//     if (withHashes) {
//         inputs.seekerValuesHash = Array(NUM_SEEKERS).fill(null);
//         inputs.seekerValuesUpdated = Array(NUM_TICKS).fill(null).map(() => Array(NUM_SEEKERS).fill(0));
//     }
//     for (let s=0; s<NUM_SEEKERS; s++) {
//         let inputValuesHash = 0;
//         const poseidon = await circomlib.buildPoseidon();

//         for (let a=0; a<cfgs[s].length; a++) {
//             const cfg = cfgs[s][a];
//             // console.log('seeker', s, action);
//             if (cfg.action == ActionKind.ENTER || cfg.action == ActionKind.EQUIP) {
//                 // console.log('hash bfr', poseidon.F.toString(inputValuesHash));
//                 const h = [
//                     inputValuesHash,
//                     packSlotConfig(cfg)
//                 ];
//                 inputValuesHash = poseidon(h);
//                 if (withHashes) {
//                     inputs.seekerValuesUpdated[cfg.tick][s] = 1;
//                 }
//                 // console.log('hash afr', poseidon.F.toString(inputValuesHash), h);
//             }
//             for (let t=cfg.tick; t<NUM_TICKS; t++) {
//                 inputs.seekerHRV[t][s] = cfg.hrv;
//                 inputs.seekerYLB[t][s] = cfg.yldb;
//                 inputs.seekerEND[t][s] = cfg.end;
//                 inputs.seekerACT[t][s] = cfg.action;
//             }
//         }

//         if (withHashes) {
//             inputs.seekerValuesHash[s] = inputValuesHash === 0 ? 0 : poseidon.F.toString(inputValuesHash);
//         }
//     }

//     return inputs;
// }
