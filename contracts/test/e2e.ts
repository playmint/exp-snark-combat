import { expect } from 'chai';
import { createDeployment, deployContracts } from "../scripts/deployContracts";
import { Session, Seeker } from "../typechain-types";
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
let sessionContract:Session;
let seekerContract:Seeker;

const numSeekers = 3;
const numTicks = 100;
const seekerGeneration = 1;

interface Prover {
    wasm: string;
    key: string;
    withHashes: boolean;
}

const PROVE_ON_CHAIN_INPUTS:Prover = {
    wasm: path.join("..", "combatnohash_js", "combatnohash.wasm"),
    key: path.join("..", "combatnohash_0001.zkey"),
    withHashes: false,
};
const PROVE_OFF_CHAIN_INPUTS:Prover = {
    wasm: path.join("..", "combat_js", "combat.wasm"),
    key: path.join("..", "combat_0001.zkey"),
    withHashes: true,
};

enum Alignment {
    NONE,
    LIGHT,
    DARK,
    ORDER,
    CHAOS,
    ARCANE
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
    yields: [BigNumber, BigNumber, BigNumber];
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


// const runs = Array(numTicks).fill(null).map((v, i) => ({tick: i, slot: i % numSeekers}));
const runs = [{tick: 10, slot: 0}]; // quick

describe('E2E', async function () {

    this.timeout(1000000000);

    before(async () => {
        // keep the signer addr
        [signer] = await ethers.getSigners();
        // wait for contract deployment to complete
        ({ sessionContract, seekerContract } = await deployContracts(deployment));
        // mint n seekers
        for (let i=0; i<numSeekers; i++) {
            await seekerContract.mint(
                signer.address,
                seekerGeneration,
                [
                    2, // str
                    2, // tough
                    1, // dex
                    4, // speed
                    5, // vit
                    6, // endur
                    7, // order
                    50 // corruption
                ],
            ).then(tx => tx.wait());
        }
    });

    runs.forEach(({tick, slot}) => { // do multiple runs for better gas comparrison

        describe(`with tick=${tick} and slot=${slot}`, () => {

            const sessionCorruption = 50;

            it("resetSessionWithOffChainStorage", async () => {
                await sessionContract.resetSessionWithOffChainStorage(sessionCorruption).then(tx => tx.wait());
                await ethers.provider.send("evm_mine", [])
            });

            it("resetSessionWithOnChainStorage", async () => {
                await sessionContract.resetSessionWithOnChainStorage(sessionCorruption).then(tx => tx.wait());
                await ethers.provider.send("evm_mine", [])
            });

            it("joinSessionWithOffChainStorage", async () => {
                for (let seekerID=1; seekerID<=numSeekers; seekerID++) {
                    await sessionContract.joinSessionWithOffChainStorage(seekerID).then(tx => tx.wait());
                }
            });

            it("joinSessionWithOnChainStorage", async () => {
                for (let seekerID=1; seekerID<=numSeekers; seekerID++) {
                    await sessionContract.joinSessionWithOnChainStorage(seekerID).then(tx => tx.wait());
                }
            });

            it("should fast forward NUM_TICKS blocks", async () => {
                for (let i=0; i<numTicks; i++) {
                    await ethers.provider.send("evm_mine", [])
                }
            });

            it("claimWithOnChainCalcOffChainStorage", async () => {
                // build the session state from the events
                const state = await getSessionState();
                console.log('session state <=== ', state);

                // build the actions data (slot configs over time) from the events
                const cfgs = state.slots.map(slot => slot.configs);
                console.log('cfg ===> ', cfgs);

                // fetch the calculated yields from the chain (this could be done offline)
                const yields = await sessionContract.getSlotYieldsWithOffChainStorage(tick, cfgs);
                console.log('yields <=== ', yields);

                // construct a claim for seeker in slot0
                const claim:Claim = {
                    tick,
                    slot: 0,
                    yields,
                };
                console.log('claim ===>', claim);

                // attempt to claim
                await sessionContract.claimWithOnChainCalcOffChainStorage(claim, cfgs).then(tx => tx.wait());
            });

            it("claimWithOnChainCalcOnChainStorage", async () => {
                // fetch the calculated yields from the chain (this could be done offline)
                const yields = await sessionContract.getSlotYieldsWithOnChainStorage(tick);
                console.log('yields <=== ', yields);

                // construct a claim for seeker in slot0
                const claim:Claim = {
                    tick,
                    slot: 0,
                    yields,
                };
                console.log('claim ===>', claim);

                // attempt to claim
                await sessionContract.claimWithOnChainCalcOnChainStorage(claim).then(tx => tx.wait());
            });

            it("claimWithOffChainCalcOffChainStorage", async () => {
                // build the session state from the events
                const state = await getSessionState();
                console.log('session state <=== ', state);

                // build the actions data (slot configs over time) from the events
                const cfgs = state.slots.map(slot => slot.configs);
                console.log('cfg ===> ', cfgs);

                // build claim and proof to the state at tick
                const [claim, proof] = await getClaimProof(cfgs, tick, slot, PROVE_OFF_CHAIN_INPUTS);
                console.log('claim ===>', claim);

                // attempt to claim
                await sessionContract.claimWithOffChainCalcOffChainStorage(claim, proof).then(tx => tx.wait());
            });

            it("claimWithOffChainCalcOnChainStorage", async () => {
                // fetch the actions data (slot configs over time) from on chain
                const cfgs = await sessionContract.getOnChainConfigs();
                console.log('cfg ===> ', cfgs);

                // build claim and proof to the state at tick
                const [claim, proof] = await getClaimProof(cfgs, tick, slot, PROVE_ON_CHAIN_INPUTS);
                console.log('claim ===>', claim);

                // attempt to claim
                await sessionContract.claimWithOffChainCalcOnChainStorage(claim, proof).then(tx => tx.wait());
            });

        });

    });


    // it("should return same outputs for both on-chain vs off-chain", async () => {
    //     // build the session state from the events
    //     const state = await getSessionState();
    //     console.log('session state <=== ', state);

    //     // pick a time and slot to verify
    //     const tick = 90;
    //     const slot = 0;

    //     // build the actions data (slot configs over time) from the events
    //     const cfgs = state.slots.map(slot => slot.configs);
    //     console.log('cfg ===> ', cfgs);

    //     // fetch on-chain calc
    //     const onChainYields = await sessionContract.getSlotYields(tick, cfgs)
    //         .then(yields => yields.map(n => n.toNumber()));

    //     // fetch off-chain calc
    //     const [claim, _] = await getClaimProof(cfgs, tick, slot);
    //     const offChainYields = claim.yields;

    //     // expect(offChainYields).to.equal(onChainYields);
    // });


});

async function getCurrentTick(): Promise<number> {
    const session = await sessionContract.session();
    const currentBlock = await provider.getBlockNumber();
    return currentBlock - session.startTick;
}

async function getSessionState(): Promise<SessionState> {
    // fetch the session config
    const session = await sessionContract.session();
    // fetch the occupied slots
    const slots: Slot[] = [];
    for (let i=0; i<numSeekers; i++) {
        const slot = await sessionContract.offChainSlots(i);
        slots.push({
            seekerID: slot.seekerID,
            hash: slot.hash,
            configs: [],
        });
    }
    // fetch all the Action events
    const events = await sessionContract.queryFilter(sessionContract.filters.SlotUpdated(), 0, 500);
    // group the Actions by their seeker slot
    events.forEach(({blockNumber, args}): Slot[] => {
        const [
            slotID,
            configs,
        ] = args;
        slots[slotID].configs.push(configs);
        return slots;
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
            yields: outputs.publicSignals.slice(0,numSeekers),
        };
        // console.log('state', state);
        return [claim, proof as ClaimProofStruct];
}

async function generateInputs(cfgs:SlotConfig[][], currentTick:number, withHashes:boolean) {

    // convert actions into expanded list of all inputs at each tick per seeker
    const inputs = {
        seekerHRV: Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0)),
        seekerYLB: Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0)),
        seekerEND: Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0)),
        seekerACT: Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0)),
        currentTick,
    } as any;
    if (withHashes) {
        inputs.seekerValuesHash = Array(numSeekers).fill(null);
        inputs.seekerValuesUpdated = Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0));
    }
    for (let s=0; s<numSeekers; s++) {
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
            for (let t=cfg.tick; t<numTicks; t++) {
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

