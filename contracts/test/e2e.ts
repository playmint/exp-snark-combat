import { expect } from 'chai';
import { createDeployment, deployContracts } from "../scripts/deployContracts";
import { Dungeon, Seeker } from "../typechain-types";
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

const numSeekers = 3;
const numTicks = 100;

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

const deployment = createDeployment(hre);
const provider = hre.ethers.provider;

let signer:SignerWithAddress;
let dungeonContract:Dungeon;
let seekerContract:Seeker;

describe('E2E', async function () {

    this.timeout(1000000000);

    before(async () => {
        // keep the signer addr
        [signer] = await ethers.getSigners();
        // wait for contract deployment to complete
        ({ dungeonContract, seekerContract } = await deployContracts(deployment));
    });

    it("should setup the battle", async () => {
        await dungeonContract.resetBattle(
            Alignment.LIGHT,
            Alignment.LIGHT,
            Alignment.LIGHT,
            Alignment.DARK,
        ).then(tx => tx.wait());

        await ethers.provider.send("evm_mine", [])
    })

    it("should mint seeker1 (id=1)", async () => {
        await seekerContract.mint(
            signer.address,
            1,
            [
                2, // str
                2, // tough
                3, // dex
                4, // speed
                5, // vit
                6, // endur
                7, // order
                0 // corruption (ignored)
            ],
        ).then(tx => tx.wait());
        expect(await seekerContract.ownerOf(1)).to.equal(signer.address);
        await ethers.provider.send("evm_mine", [])
    });

    it("should add seeker1 into the battle", async () => {
        await dungeonContract.send(
            ActionKind.ENTER,
            1, // seeker id
            0, // no attack run
            0, // no armour rune
            0  // no health rune
        );
        await ethers.provider.send("evm_mine", [])
    });

    it("should mint seeker2 (id=2)", async () => {
        await seekerContract.mint(
            signer.address,
            1,
            [
                2, // str
                2, // tough
                3, // dex
                4, // speed
                5, // vit
                6, // endur
                7, // order
                0 // corruption (ignored)
            ],
        ).then(tx => tx.wait());
        expect(await seekerContract.ownerOf(2)).to.equal(signer.address);
        await ethers.provider.send("evm_mine", [])
    });

    let state:CombatState;

    it("should generate state from events", async () => {
        state = await getState();
        expect(state.dungeonArmour).to.be.lt(100);
        expect(state.dungeonArmour).to.be.gt(50);
        expect(state.dungeonHealth).to.be.eq(100);
        expect(state.seekerArmour).to.be.lt(100);
        expect(state.seekerHealth).to.be.eq(100);
    });

    it("should not be able to claim a rune yet", async () => {
        expect(dungeonContract.claimRune(state as any)).to.be.revertedWith('not weak enough');
    });

    it("should add seeker2 into the battle", async () => {
        await dungeonContract.send(
            ActionKind.ENTER,
            2, // seeker id
            0, // no attack run
            0, // no armour rune
            0  // no health rune
        );
        await ethers.provider.send("evm_mine", [])
    });

    it("should be able to claim rune after 9 ticks with two seekers in the fight", async () => {
        state = await getState();
        expect(state.dungeonArmour).to.be.lt(30);
        await dungeonContract.claimRune(state as any);
    });

    it("should mine some more blocks until armour is defeated", async () => {
        await ethers.provider.send("evm_mine", [])
        await ethers.provider.send("evm_mine", [])
        const state = await getState();
        expect(state.dungeonArmour).to.eq(0);
    });

    it("should be able to equip seeker1 with rune during battle to improve attack", async () => {
        const nextTick = (await getCurrentTick()) + 1;
        const nextStateWithoutRune = await getState(nextTick);
        await dungeonContract.send(
            ActionKind.EQUIP,
            1, // seeker id
            1, // equip the rune we claimed
            0, // no armour rune
            0  // no health rune
        );
        const nextStateWithRune = await getState(nextTick);
        expect(nextStateWithRune.dungeonHealth).to.be.lt(nextStateWithoutRune.dungeonHealth);
    });

    it("seeker should win this battle at this rate", async () => {
        const state = await getState(99);
        expect(state.seekerHealth).to.be.gt(0);
        expect(state.dungeonHealth).to.be.eq(0);
    });

});

interface CombatState {
    dungeonArmour: number;
    dungeonHealth: number;
    seekerArmour: number;
    seekerHealth: number;
    slot: number;
    tick: number;
    pi_a: number[];
    pi_b: number[][];
    pi_c: number[];
};

async function getCurrentTick(): Promise<number> {
    const battleStart = await dungeonContract.dungeonBattleStart().then(n => n.toNumber());
    const currentBlock = await provider.getBlockNumber();
    return currentBlock - battleStart;
}

async function getState(tick?: number): Promise<CombatState> {
        // fetch all the Action events
        const events = await dungeonContract.queryFilter(dungeonContract.filters.Action(), 0, 500);
        // group the Actions by their seeker slot
        const slots = events.reduce((slots, {blockNumber, args}) => {
            const [
                kind,
                slotID,
                [
                    tick,
                    dungeonAttackArmour,
                    dungeonAttackHealth,
                    seekerAttackArmour,
                    seekerAttackHealth
                ]
            ] = args;
            slots[slotID].push({
                kind,
                tick,
                dungeonAttackArmour,
                dungeonAttackHealth,
                seekerAttackArmour,
                seekerAttackHealth
            })
            return slots;
        }, Array(numSeekers).fill(null).map(() => [] as any));
        // console.log('actions', slots);
        // fetch the current block and convert to ticks since battle started
        const currentTick = Math.min(tick ? tick : (await getCurrentTick()), 99);
        // expand each action to cover each tick
        // (this is the input the circuit needs)
        const currentSeeker = 0; // generate health for this slot (the seeker we care about)
        const inputs = await generateInputs(slots, currentSeeker, currentTick);
        // evaluate the circuit / build proof to get the valid outputs
        //
        // witness
        const wtns = {type: "mem"};
        await snarkjs.wtns.calculate(inputs, path.join("..", "combat_js", "combat.wasm"), wtns);
        // proof
        const zkey_final = fs.readFileSync(path.join("..", "combat_0001.zkey"));
        const outputs = await snarkjs.groth16.prove(zkey_final, wtns);
        // now we have the public signals and can build the current verified state
        const [
            dungeonArmour,
            dungeonHealth,
            seekerArmour,
            seekerHealth,
            slot0ValuesHash,
            slot1ValuesHash,
            slot2ValuesHash,
        ] = outputs.publicSignals;
        // verify the proof
        // const vKey = JSON.parse(fs.readFileSync(path.join("..", "verification_key.json")).toString());
        // const verification = await snarkjs.groth16.verify(vKey, outputs.publicSignals, outputs.proof);
        // expect(verification).to.be.true;
        const state = {
            dungeonArmour: parseInt(dungeonArmour, 10),
            dungeonHealth: parseInt(dungeonHealth, 10),
            seekerArmour: parseInt(seekerArmour, 10),
            seekerHealth: parseInt(seekerHealth, 10),
            tick: currentTick,
            slot: currentSeeker,
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
        // console.log('state', state);
        return state;
}

async function generateInputs(slots:any, currentSeeker:number, currentTick:number) {

    // convert actions into expanded list of all inputs at each tick per seeker
    const inputs = {
        dungeonAttackArmour: Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0)),
        dungeonAttackHealth: Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0)),
        seekerAttackArmour: Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0)),
        seekerAttackHealth: Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0)),
        currentSeeker,
        currentTick,
        seekerValuesHash: Array(numSeekers).fill(null),
        seekerValuesUpdated: Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0)),
    };
    for (let s=0; s<numSeekers; s++) {
        const actions = slots[s];
        let inputValuesHash = 0;
        const poseidon = await circomlib.buildPoseidon();

        for (let a=0; a<actions.length; a++) {
            const action = actions[a];
            // console.log('seeker', s, action);
            if (action.kind == ActionKind.ENTER || action.kind == ActionKind.EQUIP) {
                // console.log('hash bfr', poseidon.F.toString(inputValuesHash));
                const h = [
                    inputValuesHash,
                    action.dungeonAttackArmour,
                    action.dungeonAttackHealth,
                    action.seekerAttackArmour,
                    action.seekerAttackHealth,
                    action.tick,
                ];
                inputValuesHash = poseidon(h);
                inputs.seekerValuesUpdated[action.tick][s] = 1;
                // console.log('hash afr', poseidon.F.toString(inputValuesHash), h);
            }
            for (let t=action.tick; t<numTicks; t++) {
                inputs.dungeonAttackArmour[t][s] = action.dungeonAttackArmour;
                inputs.dungeonAttackHealth[t][s] = action.dungeonAttackHealth;
                inputs.seekerAttackArmour[t][s] = action.seekerAttackArmour;
                inputs.seekerAttackHealth[t][s] = action.seekerAttackHealth;
            }
        }

        inputs.seekerValuesHash[s] = inputValuesHash === 0 ? 0 : poseidon.F.toString(inputValuesHash);
    }

    return inputs;
}

