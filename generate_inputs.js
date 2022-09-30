const circomlib = require('circomlibjs');
const { BigNumber, utils } = require('ethers');

const numSeekers = 3;
const numTicks = 100;

async function main() {
    const genAction = (t, hrv, yldb) => ({
        tick: t,
        hrv,
        yldb,
        end: 100,
        action: 0, // JOIN
    });

    // actions/slotconfigs
    const cfgs = Array(numSeekers).fill(null).map(() => []);
    for (let i=0; i<numSeekers-1; i++) {
        cfgs[i].push( genAction(1, 9, 1) );
    }

    // convert actions into expanded list of all inputs at each tick per seeker
    const inputs = {
        seekerHRV: Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0)),
        seekerYLB: Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0)),
        seekerEND: Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0)),
        seekerACT: Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0)),
        currentTick: 5,
        seekerValuesHash: Array(numSeekers).fill(null),
        seekerValuesUpdated: Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0)),
    };
    for (let s=0; s<numSeekers; s++) {
        let inputValuesHash = 0;
        const poseidon = await circomlib.buildPoseidon();

        for (let a=0; a<cfgs[s].length; a++) {
            const cfg = cfgs[s][a];
            // console.log('seeker', s, action);
            if (cfg.action == 0) { // 0=join
                const h = [
                    inputValuesHash,
                    packSlotConfig(cfg)
                ];
                inputValuesHash = poseidon(h);
                inputs.seekerValuesUpdated[cfg.tick][s] = 1;
                // console.log('hash afr', poseidon.F.toString(inputValuesHash), h);
            }
            for (let t=cfg.tick; t<numTicks; t++) {
                inputs.seekerHRV[t][s] = cfg.hrv;
                inputs.seekerYLB[t][s] = cfg.yldb;
                inputs.seekerEND[t][s] = cfg.end;
                inputs.seekerACT[t][s] = cfg.action;
            }
        }

        inputs.seekerValuesHash[s] = inputValuesHash === 0 ? 0 : poseidon.F.toString(inputValuesHash);
    }

    return inputs;
}

function packSlotConfig(cfg) {
    return BigInt(0)
        | (BigInt(cfg.action) << BigInt(8))
        | (BigInt(cfg.tick) << BigInt(21))
        | (BigInt(cfg.hrv) << BigInt(34))
        | (BigInt(cfg.yldb) << BigInt(47))
        | (BigInt(cfg.end) << BigInt(60));
}

main()
    .then((data) => console.log(JSON.stringify(data)));


