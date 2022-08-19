const circom = require('circomlibjs');
const args = process.argv.slice(2);

const numSeekers = parseInt(args[0], 10);

async function main() {
    const inputs = {
        "selectedTick": 2,
        "seekerAttackArmour": Array(numSeekers).fill(1),
        "seekerAttackHealth": Array(numSeekers).fill(1),
        "dungeonAttackArmour": Array(numSeekers).fill(1),
        "dungeonAttackHealth": Array(numSeekers).fill(1),
        "dungeonArmourIn": 100,
        "dungeonHealthIn": 100,
        "seekerHealthIn": Array(numSeekers).fill(100),
        "seekerArmourIn": Array(numSeekers).fill(100),
    };

    // hash input values
    // structure of inputValues must match
    // input signals of the inputValuesHash in combat.circom
    const mimc = await circom.buildMimcSponge();
    const inputValues = [];
    inputValues.push(inputs.dungeonArmourIn);
    inputValues.push(inputs.dungeonHealthIn);
    for (let i=0; i<numSeekers; i++) {
        inputValues.push(inputs.seekerArmourIn[i]);
        inputValues.push(inputs.seekerHealthIn[i]);
    }
    const inputValuesHash = mimc.multiHash(inputValues, 0, 1);
    inputs.hashIn = mimc.F.toString( inputValuesHash );

    return inputs;
}

main()
    .then((data) => console.log(JSON.stringify(data,null,2)));


