import { Deployment } from "@anders-t/zem";
import fs from "fs";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Contract, ContractFactory } from "ethers";
import { TransactionResponse } from "@ethersproject/abstract-provider";
import { simpleVarCheckValue, mapVarCheckValue } from "./common";
import { Dungeon, Seeker, Rune, Verifier } from "../typechain-types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import * as circomlib from "circomlibjs";

export function createDeployment(hre: HardhatRuntimeEnvironment) {
    return new Deployment(hre);
};

export async function deployContracts(deployment: Deployment) {

    const [signer] = await deployment.hre.ethers.getSigners();

    const poseidonContractFactory = new ContractFactory(
        circomlib.poseidonContract.generateABI(6),
        circomlib.poseidonContract.createCode(6),
        signer
    );
    const poseidonContract = await poseidonContractFactory.deploy();

    const seekerContractArgs:any[] = [];
    const seekerContract = await deployment.deploy( {
        id: "seeker",
        contract: "src/Seeker.sol:Seeker",
        autoUpdate: true,
    }, ...seekerContractArgs) as Seeker;

    await seekerContract.setMaxSupply(1, 500);

    const runeContractArgs:any[] = [];
    const runeContract = await deployment.deploy( {
        id: "rune",
        contract: "src/Rune.sol:Rune",
        autoUpdate: true,
    }, ...runeContractArgs) as Rune;

    const verifierContractArgs:any[] = [];
    const verifierContract = await deployment.deploy( {
        id: "rune",
        contract: "src/CombatVerifier.sol:Verifier",
        autoUpdate: true,
    }, ...verifierContractArgs) as Verifier;

    const dungeonContractArgs:any[] = [
        seekerContract.address,
        runeContract.address,
        verifierContract.address,
        poseidonContract.address,
    ];
    const dungeonContract = await deployment.deploy( {
        id: "dungeon",
        contract: "src/Dungeon.sol:Dungeon",
        autoUpdate: true,
    }, ...dungeonContractArgs) as Dungeon;

    return {
        poseidonContract,
        seekerContract,
        runeContract,
        verifierContract,
        dungeonContract,
    }

};

