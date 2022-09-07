const circom = require('circomlibjs');

const numSeekers = 3;
const numTicks = 100;

async function main() {
    const genAction = (t, seekerAttack, dungeonAttack) => ({
        name: 'ENTER',
        tick: t,
        dungeonAttackArmour: dungeonAttack,
        dungeonAttackHealth: dungeonAttack,
        seekerAttackArmour: seekerAttack,
        seekerAttackHealth: seekerAttack,
    });

    // actions
    const slots = Array(numSeekers).fill(null).map(() => []);
    for (let i=0; i<numSeekers-1; i++) {
        slots[i].push( genAction(1, 9, 11) );
    }

    // convert actions into expanded list of all inputs at each tick per seeker
    const inputs = {
        dungeonAttackArmour: Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0)),
        dungeonAttackHealth: Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0)),
        seekerAttackArmour: Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0)),
        seekerAttackHealth: Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0)),
        currentSeeker: 0,
        currentTick: 99,
        seekerValuesHash: Array(numSeekers).fill(null),
        seekerValuesUpdated: Array(numTicks).fill(null).map(() => Array(numSeekers).fill(0)),
    };
    for (let s=0; s<numSeekers; s++) {
        const actions = slots[s];
        let inputValuesHash = 0;
        const poseidon = await circom.buildPoseidon();

        for (let a=0; a<actions.length; a++) {
            const action = actions[a];
            // console.log('seeker', s, action);
            if (action.name == 'ENTER' || action.name == 'EQUIP') {
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

main()
    .then((data) => console.log(JSON.stringify(data)));


