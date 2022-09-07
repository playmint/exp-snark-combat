import { Deployment } from "@anders-t/zem";
import hre from "hardhat";
import * as primarychainDeployer from "./deployContracts";

let deployment: Deployment;

async function main() {
    await hre.run("compile");

    const { createDeployment, deployContracts } = getDeployer();

    deployment = createDeployment(hre);

    await deployContracts(deployment);
}

function getDeployer() {
    return primarychainDeployer;
}

main()
    .catch((error) => {
        console.error(error);
        process.exitCode = 1;
    })
    .finally(() => {
        if (deployment && hre.network.name !== "hardhat") {
            deployment.writeToFile();
        }
    });
