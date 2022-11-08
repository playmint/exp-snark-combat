import { expect } from 'chai';
import { createDeployment, deployContracts } from "../scripts/deployContracts";
import { Mod, Seeker } from "../typechain-types";
import { ClaimProofStruct } from "../typechain-types/src/Session.sol/Session";
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

const deployment = createDeployment(hre);
const provider = hre.ethers.provider;

let signer:SignerWithAddress;
let seekerContract:Seeker;
let modContract:Mod;

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

enum ActionKind {
    ENTER,
    EQUIP,
    DRINK,
    LEAVE
}

interface Slot {
    hash: BigNumber;
    seekerID: number;
    configs: SlotConfig[];
}

interface SlotConfig {
  action: ActionKind;
  tick: number;
  hrv: number;
  yldb: number;
  end: number;
};

interface Claim {
    slot: number;
    tick: number;
    yields: any;
}

interface SessionState {
    seekerCap: number;
    // enduranceReq: number;
    affinity: number;
    // rewardSupply: number;
    // bonusSupply: number;
    startTick: number;
    slots: Slot[];
}

interface CombatState {
    sessionArmour: number;
    sessionHealth: number;
    seekerArmour: number;
    seekerHealth: number;
    slot: number;
    tick: number;
    pi_a: number[];
    pi_b: number[][];
    pi_c: number[];
};


describe('E2E', async function () {

    this.timeout(1000000000);

    before(async () => {
        // keep the signer addr
        [signer] = await ethers.getSigners();
        // wait for contract deployment to complete
        ({ seekerContract, modContract } = await deployContracts(deployment));
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

    // it("resetSession", async () => {
    //     const txs = [];
    //     txs.push(await sessionContract.resetSessionWithOffChainStorage(sessionCorruption));
    //     txs.push(await sessionContract.resetSessionWithOnChainStorage(sessionCorruption));
    //     await mine(txs);
    // });

    // it("note session start block", async () => {
    //     sessionStartBlock = await provider.getBlockNumber();
    // });

    // it("joinSession", async () => {
    //     const txs = [];
    //     for (let seekerID=1; seekerID<=NUM_SEEKERS; seekerID++) {
    //         txs.push(await sessionContract.joinSessionWithOffChainStorage(seekerID));
    //         txs.push(await sessionContract.joinSessionWithOnChainStorage(seekerID));
    //     }
    //     await mine(txs);
    // });

    // it("modSession", async () => {
    //     for (let a=0; a<NUM_ACTIONS; a++) {
    //         const txs = [];
    //         for (let seekerID=1; seekerID<=NUM_SEEKERS; seekerID++) {
    //             txs.push(await sessionContract.modSessionWithOffChainStorage(seekerID));
    //             txs.push(await sessionContract.modSessionWithOnChainStorage(seekerID));
    //         }
    //         await mine(txs);
    //     }
    // });

    // it("should fast forward to NUM_TICKS blocks", async () => {
    //     const isPastLastTick = async ():Promise<boolean> => {
    //         const currentBlock = await provider.getBlockNumber();
    //         return (currentBlock - sessionStartBlock) > (NUM_TICKS+1);
    //     }
    //     while (!(await isPastLastTick())) {
    //         await mine([]);
    //     }
    //     // reenable auto-mine from this point
    //     await ethers.provider.send("evm_setAutomine", [true]);
    // });

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

async function getCurrentTick(): Promise<number> {
    const session = await sessionContract.session();
    const currentBlock = await provider.getBlockNumber();
    return currentBlock - session.startTick;
}

async function getSessionState(fromBlock: number): Promise<SessionState> {
    // fetch the session config
    const session = await sessionContract.session();
    // fetch the occupied slots
    const slots: Slot[] = [];
    for (let i=0; i<NUM_SEEKERS; i++) {
        const slot = await sessionContract.offChainSlots(i);
        slots.push({
            seekerID: slot.seekerID,
            hash: slot.hash,
            configs: [],
        });
    }
    // fetch all the Action events
    const events = await sessionContract.queryFilter(sessionContract.filters.SlotUpdated(), fromBlock, 50000);
    // group the Actions by their seeker slot
    events.forEach(({blockNumber, args}) => {
        const [
            slotID,
            config,
        ] = args;
        slots[slotID].configs.push(config);
    });

    return {
        seekerCap: session.seekerCap,
        affinity: session.affinity,
        startTick: session.startTick,
        slots,
    }
}

async function getClaimProof(cfgs: SlotConfig[][], tick:number, slot:number, prover:Prover): Promise<[Claim, ClaimProofStruct]> {
        // console.log('actions', slots);
        // expand each action to cover each tick
        // (this is the input the circuit needs)
        const inputs = await generateInputs(cfgs, tick, prover.withHashes);
        console.log('circuit inputs ==>', inputs);
        // evaluate the circuit / build proof to get the valid outputs
        //
        // witness
        const wtns = {type: "mem"};
        await snarkjs.wtns.calculate(inputs, prover.wasm, wtns);
        // proof
        const zkey_final = fs.readFileSync(prover.key);
        const outputs = await snarkjs.groth16.prove(zkey_final, wtns);
        // now we have the public signals and can build the current verified state
        console.log('circuit outputs ==>', JSON.stringify(outputs.publicSignals));
        // expect(
        //     outputs.publicSignals.slice(0,claim.yields.length)
        // ).to.equal(
        //     claim.yields.map(n => n.toNumber())
        // );
        // [optionally] verify the proof locally
        // const vKey = JSON.parse(fs.readFileSync(path.join("..", "verification_key.json")).toString());
        // const verification = await snarkjs.groth16.verify(vKey, outputs.publicSignals, outputs.proof);
        // expect(verification).to.be.true;
        const proof = {
            pi_a: [
                outputs.proof.pi_a[0],
                outputs.proof.pi_a[1],
            ],
            pi_b: [
                [outputs.proof.pi_b[0][1], outputs.proof.pi_b[0][0]],
                [outputs.proof.pi_b[1][1], outputs.proof.pi_b[1][0]],
            ],
            pi_c: [
                outputs.proof.pi_c[0],
                outputs.proof.pi_c[1],
            ],
        };
        // construct the claim
        const claim = {
            tick,
            slot,
            yields: outputs.publicSignals.slice(0,NUM_SEEKERS),
        };
        // console.log('state', state);
        return [claim, proof as ClaimProofStruct];
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

function packSlotConfig(cfg:SlotConfig) {
    return BigInt(0)
        | (BigInt(cfg.action) << BigInt(8))
        | (BigInt(cfg.tick) << BigInt(21))
        | (BigInt(cfg.hrv) << BigInt(34))
        | (BigInt(cfg.yldb) << BigInt(47))
        | (BigInt(cfg.end) << BigInt(60));
}

