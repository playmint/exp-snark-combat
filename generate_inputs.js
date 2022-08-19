const circom = require('circomlibjs');
const args = process.argv.slice(2);

const numSeekers = parseInt(args[0], 10);

async function main() {
    const inputs = {
        "selectedTick": 98,
        "seekerAttackArmour": Array(numSeekers).fill(5),
        "seekerAttackHealth": Array(numSeekers).fill(5),
        "dungeonAttackArmour": Array(numSeekers).fill(10),
        "dungeonAttackHealth": Array(numSeekers).fill(10),
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
        inputValues.push(inputs.seekerAttackArmour[i]);
        inputValues.push(inputs.seekerAttackHealth[i]);
        inputValues.push(inputs.dungeonAttackArmour[i]);
        inputValues.push(inputs.dungeonAttackHealth[i]);
    }
    const inputValuesHash = mimc.multiHash(inputValues, 0, 1);
    inputs.hashIn = mimc.F.toString( inputValuesHash );

    return inputs;
}

main()
    .then((data) => console.log(JSON.stringify(data,null,2)));


