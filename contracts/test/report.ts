import fs from 'fs';
import path from 'path';
import util from 'util';
import { exec } from 'child_process';

const execute = util.promisify(exec);

interface Variant {
    seekers: number;
    ticks: number;
    actions: number;
}

interface Report extends Variant {
    data: GasData[];
}

interface GasData {
    method: string;
    gas: number[]; // gas cost of each recorded call
}

interface Prover {
    wasmPath: string;
    keyPath: string;
    verifierPath: string;
}

function variants():Variant[] {
    const nSeekers = [1,2,4,8];
    const nTicks = [8,16,32,64,128,255];
    const nActions = [0,1,2];

    const variants:Variant[] = [];
    nSeekers.forEach((seekers) => {
        nTicks.forEach((ticks) => {
            nActions.forEach((actions) => {
                const variant = {
                    seekers,
                    ticks,
                    actions,
                };
                const spareTicks = ticks - (seekers/8) - (actions*seekers/8);
                if (spareTicks <= 4) {
                    console.log('spare', spareTicks, variant);
                    console.log(`skipping variant`, variant, 'as infeasible'); // can't fit the actions/join into the ticks
                }
                variants.push(variant);
            });
        });
    }, []);

    return variants;
}

async function getReport(variant:Variant): Promise<Report> {
    // check if a datafile already exists and just use that instead
    const gasReportPath = path.join('./circuits', `report_${variant.seekers}_${variant.ticks}_${variant.actions}.json`);
    if (fs.existsSync(gasReportPath)) {
        console.log(`loading ${gasReportPath}`);
        return {
            ...variant,
            data: JSON.parse(fs.readFileSync(gasReportPath).toString()),
        };
    }

    // remove tmp if exist
    const gasReportTmpPath = path.join('gasReporterOutput.json');
    if (fs.existsSync(gasReportTmpPath)) {
        fs.unlinkSync(gasReportTmpPath);
    }

    // write the circuit for the hashed variant
    const proverWithHash = await compile(`combatwithhash_${variant.seekers}_${variant.ticks}`,`
pragma circom 2.0.0;

include "../../circuits/templates.circom";

component main {
    public [
        seekerValuesHash,
        currentTick
    ]
} = Combat(${variant.seekers}, ${variant.ticks});
`);

    // write the circuit for the no hash variant
    const proverNoHash = await compile(`combatnohash_${variant.seekers}_${variant.ticks}`,`pragma circom 2.0.0;

include "../../circuits/templates.circom";

component main {
    public [
        seekerHRV,
        seekerYLB,
        seekerEND,
        seekerACT,
        currentTick
    ]
} = CombatNoHash(${variant.seekers}, ${variant.ticks});
`);


    // build a subprocess to execute tests with the given environment
    const env = {
        NUM_SEEKERS: variant.seekers.toString(),
        NUM_TICKS: variant.ticks.toString(),
        NUM_ACTIONS: variant.actions.toString(),
        NOHASH_WASM_PATH: proverNoHash.wasmPath,
        NOHASH_KEY_PATH: proverNoHash.keyPath,
        WITHHASH_WASM_PATH: proverWithHash.wasmPath,
        WITHHASH_KEY_PATH: proverWithHash.keyPath,
        NODE_OPTIONS: "--max-old-space-size=16000", // eek using all the ram
    };
    console.log(`building ${gasReportPath}`, new Date());
    try {
        const { stdout } = await execute('hardhat test --verbose test/e2e.ts', {
            env: {
                ...process.env,
                ...env,
                REPORT_GAS: 'true',
                CI: 'true',
            },
        });
    } catch(err:any) {
        throw new Error(err.stdout || err);
    }

    // process gas report into something less noisey and store it
    const gasReportTmp = JSON.parse(fs.readFileSync(gasReportTmpPath).toString());
    const data = Object.values(gasReportTmp.info.methods)
        .filter((o:any) => o.gasData.length > 0)
        .map((o:any) => ({method: o.method as string, gas: o.gasData as number[]}));

    // write the data to file
    fs.writeFileSync(gasReportPath, JSON.stringify(data));
    console.log('data', JSON.stringify(data));

    // return it
    return {
        ...variant,
        data,
    };
}

async function compile(circuitName:string, circuitSource:string): Promise<Prover> {
    console.log('compiling', circuitName);
    const circuitPath = path.join('./circuits', circuitName + '.circom');
    if(!fs.existsSync(circuitPath)){
        fs.writeFileSync(circuitPath, circuitSource);
    }

    const wasmPath = path.join('./circuits', circuitName + '_js', circuitName + '.wasm');
    if(!fs.existsSync(wasmPath)){
        const { stdout } = await execute(`/Users/chrisfarms/.cargo/bin/circom ${circuitPath} --wasm --r1cs -o circuits`);
        console.log('compiled ok', stdout);
    }

    const r1csPath = path.join('./circuits', circuitName + '.r1cs');
    const keyPath = path.join('./circuits', circuitName + '_0001.zkey');
    if(!fs.existsSync(keyPath)){
        const { stdout } = await execute(`npx snarkjs groth16 setup ${r1csPath} ../pot20_final.ptau ${keyPath}`);
        console.log('setup ok', stdout);
    }

    const verifierPath = path.join('./src', circuitName + '.sol');
    if(!fs.existsSync(verifierPath)){
        const { stdout } = await execute(`npx snarkjs zkey export solidityverifier ${keyPath} ${verifierPath}`);
        console.log('verifier contract ok', stdout);
    }
    return {
        wasmPath,
        keyPath,
        verifierPath,
    };
}

async function main() {
    // load all the reports
    const vars = variants();
    const reports:Report[] = [];
    for (let i=0; i<vars.length; i++) {
        const variant = vars[i];
        const report = await getReport(variant);
        reports.push(report);
    }
    // do something interesting with the data
    fs.writeFileSync('rawReport.js', `window.raw = `+JSON.stringify(reports)+`;`);

}

main().then(() => console.log('OK'));
