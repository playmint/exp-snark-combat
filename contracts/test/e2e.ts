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
    startBlock: BigNumber,
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
                    0, // criticalHit

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
            GameObjectAttr.health,
            10,
        ).then(tx => tx.wait());
        await modContract.mint(
            signer.address, 
            GameObjectAttr.attack,
            10,
        ).then(tx => tx.wait());

        // manual mining mode
        // await ethers.provider.send("evm_setAutomine", [false]);
    });


    const tick = NUM_TICKS; // always prove this number of ticks
    const slot = 0; // always prove this slot


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

    it("Should be able to equip 2 mods ", async () => {
        // Equip mods 1 and 2
        await modContract.equip(1, 1).then(tx => tx.wait());
        await modContract.equip(2, 1).then(tx => tx.wait());
        
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
    })

    it("Should instantiate and join a session", async() => {
        // manual mining mode
        await ethers.provider.send("evm_setAutomine", [false]);

        const pos = {x: 1024, y: 1024};

        const txs: any = [];
        txs.push(await combatManager.join(pos, 1)); //.then(tx => tx.wait());
        txs.push(await combatManager.join(pos, 2)); //.then(tx => tx.wait());
        txs.push(await combatManager.join(pos, 3)); //.then(tx => tx.wait());

        await mine(txs);

        const sessionAddr = await combatManager.getSession(pos);
        expect(sessionAddr, "Expected session contract to be instantiated").to.not.eq("0x0000000000000000000000000000000000000000");

        const session = await ethers.getContractAt("CombatSession", sessionAddr);
        const startBlock = (await session.startBlock()).toNumber();

        const state = await getSessionState(pos, startBlock);

        // console.log(`state:`, state.slots[0], state.slots[1], state.slots[2]);

        expect(state.slots[1].configs[0].tick, "Expect last two joiners to join on the same tick").to.eq(state.slots[2].configs[0].tick)
    })

    it("Seeker that leaves before the others should get a lower yield", async() => {
        const pos = {x: 1024, y: 1024};
        
        for (var i = 0; i < 10; i++) {
            await ethers.provider.send("evm_mine", []);
        }

        const txs: any = [];
        txs.push(await combatManager.leave(pos, 3));
        await mine(txs);

        for (var i = 0; i < NUM_TICKS; i++) {
            await ethers.provider.send("evm_mine", []);
        }

        // -- Get state
        const sessionAddr = await combatManager.getSession(pos);
        const session = await ethers.getContractAt("CombatSession", sessionAddr);
        const startBlock = (await session.startBlock()).toNumber();
        const state = await getSessionState(pos, startBlock);

        console.log(`state:`, state.slots[0], state.slots[1], state.slots[2]);

        const explodedState = explodeState(state, NUM_TICKS);

        // -- Check exploded state
        state.slots[2].configs.forEach( config => {
            expect(config, "Expected config WITH tick to match exploded config AT tick").to.eq(explodedState.slots[2].configs[config.tick]);
        })

        
    })

    // // THIS ONE
    // it("claimWithOnChainCalcOffChainStorage", async () => {
    //     // build the session state from the events
    //     const state = await getSessionState(sessionStartBlock);
    //     console.log('session state <=== ', state);

    //     // build the actions data (slot configs over time) from the events
    //     const cfgs = state.slots.map(slot => slot.configs);
    //     console.log('cfg ===> ', cfgs);

    //     // fetch the calculated yields from the chain (this could be done offline)
    //     const yields = await sessionContract.getSlotYieldsWithOffChainStorage(tick, cfgs);
    //     console.log('yields <=== ', yields);

    //     // construct a claim for seeker in slot0
    //     const claim:Claim = {
    //         tick,
    //         slot: 0,
    //         yields,
    //     };
    //     console.log('claim ===>', claim);

    //     // attempt to claim
    //     await sessionContract.claimWithOnChainCalcOffChainStorage(claim, cfgs).then(tx => tx.wait());
    // });

});

async function getCurrentTick(position: Position): Promise<number> {
    const sessionAddr = await combatManager.getSession(position);
    const session = await ethers.getContractAt("CombatSession", sessionAddr);
    const startBlock = (await session.startBlock()).toNumber();

    const currentBlock = await provider.getBlockNumber();
    return currentBlock - startBlock;
}

async function getSessionState(position: Position, fromBlock: number): Promise<SessionState> {
    // fetch the session config
    const sessionAddr = await combatManager.getSession(position);
    const session = await ethers.getContractAt("CombatSession", sessionAddr);

    const startBlock = await session.startBlock();

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

async function generateInputs(cfgs:SlotConfig[][], currentTick:number, withHashes:boolean) {

    // convert actions into expanded list of all inputs at each tick per seeker
    const inputs = {
        seekerHRV: Array(NUM_TICKS).fill(null).map(() => Array(NUM_SEEKERS).fill(0)),
        seekerYLB: Array(NUM_TICKS).fill(null).map(() => Array(NUM_SEEKERS).fill(0)),
        seekerEND: Array(NUM_TICKS).fill(null).map(() => Array(NUM_SEEKERS).fill(0)),
        seekerACT: Array(NUM_TICKS).fill(null).map(() => Array(NUM_SEEKERS).fill(0)),
        currentTick,
    } as any;
    if (withHashes) {
        inputs.seekerValuesHash = Array(NUM_SEEKERS).fill(null);
        inputs.seekerValuesUpdated = Array(NUM_TICKS).fill(null).map(() => Array(NUM_SEEKERS).fill(0));
    }
    for (let s=0; s<NUM_SEEKERS; s++) {
        let inputValuesHash = 0;
        const poseidon = await circomlib.buildPoseidon();

        for (let a=0; a<cfgs[s].length; a++) {
            const cfg = cfgs[s][a];
            // console.log('seeker', s, action);
            if (cfg.action == ActionKind.ENTER || cfg.action == ActionKind.EQUIP) {
                // console.log('hash bfr', poseidon.F.toString(inputValuesHash));
                const h = [
                    inputValuesHash,
                    packSlotConfig(cfg)
                ];
                inputValuesHash = poseidon(h);
                if (withHashes) {
                    inputs.seekerValuesUpdated[cfg.tick][s] = 1;
                }
                // console.log('hash afr', poseidon.F.toString(inputValuesHash), h);
            }
            for (let t=cfg.tick; t<NUM_TICKS; t++) {
                inputs.seekerHRV[t][s] = cfg.hrv;
                inputs.seekerYLB[t][s] = cfg.yldb;
                inputs.seekerEND[t][s] = cfg.end;
                inputs.seekerACT[t][s] = cfg.action;
            }
        }

        if (withHashes) {
            inputs.seekerValuesHash[s] = inputValuesHash === 0 ? 0 : poseidon.F.toString(inputValuesHash);
        }
    }

    return inputs;
}
