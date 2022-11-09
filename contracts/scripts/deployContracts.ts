import { Deployment } from "@anders-t/zem";
import fs from "fs";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Contract, ContractFactory } from "ethers";
import { TransactionResponse } from "@ethersproject/abstract-provider";
import { simpleVarCheckValue, mapVarCheckValue } from "./common";
import { CombatManager, Mod, Seeker } from "../typechain-types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import * as circomlib from "circomlibjs";

export function createDeployment(hre: HardhatRuntimeEnvironment) {
    return new Deployment(hre);
};

const NUM_SEEKERS = parseInt(process.env.NUM_SEEKERS || '-1');
const NUM_TICKS = parseInt(process.env.NUM_TICKS || '-1');

export async function deployContracts(deployment: Deployment) {

    const [signer] = await deployment.hre.ethers.getSigners();

    const poseidonContractFactory = new ContractFactory(
        circomlib.poseidonContract.generateABI(2),
        circomlib.poseidonContract.createCode(2),
        signer
    );
    const poseidonContract = await poseidonContractFactory.deploy();

    const seekerContractArgs:any[] = [];
    const seekerContract = await deployment.deploy( {
        id: "seeker",
        contract: "src/Seeker.sol:Seeker",
        autoUpdate: true,
    }, ...seekerContractArgs) as Seeker;

    await seekerContract.setMaxSupply(1, 500).then(tx => tx.wait());

    const modContract = await deployment.deploy({
        id: "mod",
        contract: "src/Mod.sol:Mod",
        autoUpdate: true,
    }) as Mod;
    await modContract.setSeekerContract(seekerContract.address).then(tx => tx.wait());

    const combatManager = await deployment.deploy( 
        {
            id: "sessionManager",
            contract: "src/combat/CombatManager.sol:CombatManager",
            autoUpdate: true
        },
        seekerContract.address,
        poseidonContract.address
    ) as CombatManager;

    // const verifierWithHashContractArgs:any[] = [];
    // const verifierWithHashContract = await deployment.deploy( {
    //     id: "verifierWithHash",
    //     contract: `src/combatwithhash_${NUM_SEEKERS}_${NUM_TICKS}.sol:Verifier`,
    //     autoUpdate: true,
    // }, ...verifierWithHashContractArgs) as Verifier;

    // const verifierNoHashContractArgs:any[] = [];
    // const verifierNoHashContract = await deployment.deploy( {
    //     id: "verifierNoHash",
    //     contract: `src/combatnohash_${NUM_SEEKERS}_${NUM_TICKS}.sol:Verifier`,
    //     autoUpdate: true,
    // }, ...verifierNoHashContractArgs) as Verifier;

    // const dungeonContractArgs:any[] = [
    //     seekerContract.address,
    //     verifierWithHashContract.address,
    //     verifierNoHashContract.address,
    //     poseidonContract.address,
    // ];
    // const sessionContract = await deployment.deploy( {
    //     id: "session",
    //     contract: "src/Session.sol:Session",
    //     autoUpdate: true,
    // }, ...dungeonContractArgs) as Session;

    return {
        seekerContract,
        modContract,
        combatManager
        // poseidonContract,
        // verifierWithHashContract,
        // verifierNoHashContract,
        // sessionContract,
    }

};

