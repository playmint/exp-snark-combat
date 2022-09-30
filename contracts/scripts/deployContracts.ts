import { Deployment } from "@anders-t/zem";
import fs from "fs";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Contract, ContractFactory } from "ethers";
import { TransactionResponse } from "@ethersproject/abstract-provider";
import { simpleVarCheckValue, mapVarCheckValue } from "./common";
import { Session, Seeker, Rune, Verifier } from "../typechain-types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import * as circomlib from "circomlibjs";

export function createDeployment(hre: HardhatRuntimeEnvironment) {
    return new Deployment(hre);
};

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

    await seekerContract.setMaxSupply(1, 500);

    const verifierWithHashContractArgs:any[] = [];
    const verifierWithHashContract = await deployment.deploy( {
        id: "rune",
        contract: "src/CombatVerifier.sol:Verifier",
        autoUpdate: true,
    }, ...verifierWithHashContractArgs) as Verifier;

    const verifierNoHashContractArgs:any[] = [];
    const verifierNoHashContract = await deployment.deploy( {
        id: "rune",
        contract: "src/CombatNoHashVerifier.sol:Verifier",
        autoUpdate: true,
    }, ...verifierNoHashContractArgs) as Verifier;

    const dungeonContractArgs:any[] = [
        seekerContract.address,
        verifierWithHashContract.address,
        verifierNoHashContract.address,
        poseidonContract.address,
    ];
    const sessionContract = await deployment.deploy( {
        id: "session",
        contract: "src/Session.sol:Session",
        autoUpdate: true,
    }, ...dungeonContractArgs) as Session;

    return {
        poseidonContract,
        seekerContract,
        verifierWithHashContract,
        verifierNoHashContract,
        sessionContract,
    }

};

