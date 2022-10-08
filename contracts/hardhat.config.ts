import { HardhatUserConfig } from "hardhat/config";
import "hardhat-preprocessor";
import fs from 'fs';
import path from "path";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-chai-matchers";
import "@typechain/hardhat";
import "hardhat-gas-reporter"
import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from "hardhat/builtin-tasks/task-names";
import { subtask } from "hardhat/config";


function getRemappings() {
    return fs
        .readFileSync("remappings.txt", "utf8")
        .split("\n")
        .filter(Boolean) // remove empty lines
        .map((line) => line.trim().split("="));
}

// injected into session.sol depending on NUM_TICKS
const NUM_SEEKERS = parseInt(process.env.NUM_SEEKERS || '3');
const NUM_TICKS = parseInt(process.env.NUM_TICKS || '100');
const rand = [31,74,61,10,64,27,22,24,92,31,82,16,61,2,22,20,64,70,57,18,2,61,30,96,44,52,48,31,14,47,79,7,15,33,46,43,51,0,39,9,49,47,64,37,55,75,50,11,38,50,10,39,48,69,95,14,50,21,38,69,74,68,27,54,66,27,92,6,52,31,26,38,45,10,75,74,68,19,84,4,34,64,87,81,29,42,1,19,81,59,57,29,5,50,69,54,22,0,77,37,9,6,62,89,50,4,74,20,3,70,34,19,56,4,25,22,30,83,34,26,97,79,11,6,70,26,98,0,72,13,73,13,69,33,60,41,24,79,99,60,18,75,22,80,33,0,58,96,58,57,32,20,88,96,23,71,9,13,49,1,99,52,44,97,52,24,31,62,34,14,1,85,23,60,4,36,81,4,94,3,39,0,10,52,77,52,69,30,50,8,72,0,0,39,60,70,36,17,91,97,61,91,52,31,85,23,85,75,68,86,58,64,18,98,48,57,29,88,25,31,43,23,67,95,4,25,12,69,61,55,44,66,13,56,31,57,94,13,37,99,3,16,73,83,35,2,30,6,17,43,81,35,57,24,23,24,3,11,99,80,45,32,15,44,81,37,35,8,39,36,36,93,7,20,4,9,20,94,41,10,92,47,80,37,77,42,28,47,87,82,41,9,49,18,50,28,49,7,85,73,32,83,90,32,81,82,43,27,37,91,52,65,68,86,45,27,9,69,49,96,66,68,72,9,1,8,0,92,54,10,66,52,41,83,10,84,3,91,94,59,33,95,80,82,58,96,25,24,79,61,45,94,8,65,28,48,3,63,59,36,60,55,36,87,55,64,36,66,95,36,90,17,8,83,44,23,7,51,81,5,57,67,79,28,80,66,17,66,93,9,40,43,45,49,21,34,37,71,52,41,51,55,37,91,46,25,33,58,45,84,7,98,0,19,71,83,89,12,17,33,8,20,60,52,6,69,4,97,47,49,98,88,17,32,55,71,60,26,10,93,25,67,48,11,45,71,65,68,61,34,78,16,34,46,53,96,76,51,36,83,96,21,25,76,41,31,96,4,31,88,69,69,38,84,31,36,20,35,78,21,33,78,40,91,7,64,31,33,20,63,42,54,68,87,28,19,96,82,99,78,2,49,32,41,35,16,14,18,38,49,65,36,44,28,54,37,59,65,76,52,58,76,38,91,37,94,15,45,43,31,40,57,74,35,92,62,63,78,2,90,28,41,51,48,63,84,95,11,32,45,66,24,41,24,6,44,15,2,2,9,80,65,90,21,78,52,78,9,54,58,65,14,86,98,83,99,88,15,57,47,94,66,57,77,74,63,63,47,98,25,78,63,45,5,73,53,85,92,20,36,65,14,85,66,95,12,20,95,87,96,96,62,17,29,19,80,12,56,92,70,11,73,84,40,98,55,6,24,77,73,2,94,18,64,83,46,66,95,3,82,21,34,9,98,32,5,25,57,69,77,42,89,17,82,29,23,78,66,40,67,2,25,37,47,87,43,88,1,56,99,59,79,4,88,5,4,36,43,42,23,29,79,98,47,52,92,85,45,14,59,56,6,85,86,25,41,87,82,24,36,73,46,10,27,32,50,99,43,99,8,34,24,3,9,37,93,35,89,23,8,2,24,89,93,9,6,74,28,2,12,91,26,64,71,98,83,10,58,32,19,24,13,56,82,45,30,83,19,90,1,99,39,74,7,32,14,65,63,50,47,4,44,2,73,66,13,75,75,30,88,32,10,89,96,84,63,65,1,53,68,73,57,11,91,89,68,18,78,41,28,7,3,73,98,3,80,41,86,97,11,10,70,89,61,39,24,84,91,32,92,36,51,22,85,26,55,69,7,40,49,55,66,78,35,28,90,0,25,50,45,83,50,45,9,41,1,4,54,28,98,21,26,50,59,98,65,19,10,17,47,80,19,5,14,26,30,9,83,63,16,88,19,57,1,17,79,81,84,22,85,63,16,45,60,44,91,87,6,5,63,58,34,21,28,34,43,55,52,19,40,82,13,87,83,13,17,83,51,9,91,48,1,53,74,93,71,4,12,88,60,68,13,31,67,16,66,2,42,78,96,78,73,39,27,58,66,56,87,88,97,45,23,31,12,25,91,90,32,65,56,43,90,4,26,65,19,26,63,87,57,17,27,10,31,55,89,45,31,11,28,47,56,88,64,74,96,15,47,99,62,81,15,14,46,58,5,53,44,23,72,31,25,8,95,6,89,86,2,85,30,18,26,21,6,16,54,40,95,13,27].slice(0,NUM_TICKS);

// we generates LOTS of verifier contracts
// which cripples running hardhat test
// so let's try to ignore the ones we don't care about
subtask(
    TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS,
    async (_, { config }, runSuper) => {
        const withhashverifierMatcher = new RegExp(`combatwithhash_${NUM_SEEKERS}_${NUM_TICKS}`);
        const nohashverifierMatcher = new RegExp(`combatnohash_${NUM_SEEKERS}_${NUM_TICKS}`);
        const paths = await runSuper();
        return paths
            .filter((solidityFilePath:string) => {
                const relativePath = path.relative(config.paths.sources, solidityFilePath)
                if (/combat(with|no)hash_/.test(relativePath) && !withhashverifierMatcher.test(relativePath) && !nohashverifierMatcher.test(relativePath)) {
                    return false;
                }
                return true;
            })
    }
);

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.11",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200
            }
        }
    },
    // circom: {
    //     inputBasePath: "./circuits",
    //     outputBasePath: "./circuits",
    //     ptau: "../../pot18_final.ptau",
    //     circuits: [
    //         { name: `combatwithhash_${process.env.NUM_SEEKERS}_${process.env.NUM_TICKS}` },
    //         { name: `combatnohash_${process.env.NUM_SEEKERS}_${process.env.NUM_TICKS}` },
    //     ],
    // },
    preprocess: {
        eachLine: (hre) => ({
            transform: (line: string) => {
                if (line.match(/^\s*import /i)) {
                    getRemappings().forEach(([find, replace]) => {
                        if (line.match(find)) {
                            line = line.replace(find, replace);
                        }
                    });
                }
                if (line.match(/^pragma solidity/)) {
                    line = 'pragma solidity ^0.8.11;';
                }
                if (line.match(/CONFIG:NUM_SEEKERS/)) {
                    line = `uint constant NUM_SEEKERS = ${NUM_SEEKERS};`;
                }
                if (line.match(/CONFIG:NUM_TICKS/)) {
                    line = `uint constant NUM_TICKS = ${NUM_TICKS};`;
                }
                if (line.match(/CONFIG:RAND/)) {
                    line = `uint[NUM_TICKS] rand = ${JSON.stringify(rand)};`;
                }
                return line;
            },
        }),
    },
    paths: {
        sources: "./src",
        cache: "./cache_hardhat",
    },
    networks: {
        hardhat: {
            blockGasLimit: 600000000000,
            allowUnlimitedContractSize: true,
            mining: {
                mempool: { order: 'fifo' }
            },
        },
        localhost: {
            url: "http://127.0.0.1:8545",
            accounts: [
                "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
            ]

        },
    },
    mocha: {
        bail: true
    },
    gasReporter: {
        enabled: (process.env.REPORT_GAS) ? true : false,
        currency: 'USD',
        token: 'MATIC',
        gasPrice: 60,
        gasPriceApi: 'https://api.polygonscan.com/api?module=proxy&action=eth_gasPrice',
        showTimeSpent: true,
        coinmarketcap: "07e102d0-c19f-4656-b25a-5604dcb89848" // coincap API key not very sensitive, mainly for rate limit
    },
};

export default config;
