import { HardhatUserConfig } from "hardhat/config";
import "hardhat-preprocessor";
import fs from 'fs';
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-chai-matchers";
import "@typechain/hardhat";
import "hardhat-gas-reporter"


function getRemappings() {
    return fs
        .readFileSync("remappings.txt", "utf8")
        .split("\n")
        .filter(Boolean) // remove empty lines
        .map((line) => line.trim().split("="));
}

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
            blockGasLimit: 600000000,
            allowUnlimitedContractSize: true,
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
    }
};

export default config;
