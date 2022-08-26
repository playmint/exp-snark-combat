const circom = require('circomlibjs');

const numSeekers = 10;
const numTicks = 100;
const numActions = 100;

async function main() {
    const inputs = {
        // "selectedTick": 10,
        "seekerAttackArmour": Array(numSeekers).fill(5),
        "seekerAttackHealth": Array(numSeekers).fill(10),
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
    // ------------------
    // begin hackery
    // -----------------
    // [!]: hack up mimc to support our shoddy insecure low numRounds
    //      this is known to have poor collison resistance,
    //      but 220 rounds takes up too many constraints in the circuit
    //      so until theres a workaround for this I'm gonna just use
    //      it insecurely
    const SEED = "mimcsponge";
    const NROUNDS = 2; // should be 220 to be secure
    mimc.cts = mimc.getConstants(SEED, NROUNDS);
    // end hackery
    // -----------------
    const inputValues = [];
    inputValues.push(inputs.dungeonArmourIn);
    inputValues.push(inputs.dungeonHealthIn);
    for (let i=0; i<numSeekers; i++) {
        inputValues.push(inputs.seekerArmourIn[i]);
        inputValues.push(inputs.seekerHealthIn[i]);
        // inputValues.push(inputs.seekerAttackArmour[i]);
        // inputValues.push(inputs.seekerAttackHealth[i]);
        // inputValues.push(inputs.dungeonAttackArmour[i]);
        // inputValues.push(inputs.dungeonAttackHealth[i]);
    }
    const inputValuesHash = mimc.multiHash(inputValues, 0, 1);
    // inputs.hashIn = mimc.F.toString( inputValuesHash );

    return inputs;
}

async function main2() {
    // generate N dummy states
    // each state is the result of applying each action from the list
    // ie there is one new state per action
    const states = Array(1).fill(null).map((_, i) => {
        return {
            dungeonAttackArmour: Array(numSeekers).fill(9),
            dungeonAttackHealth: Array(numSeekers).fill(9),
            seekerAttackArmour: Array(numSeekers).fill(2),
            seekerAttackHealth: Array(numSeekers).fill(2),
        };
    });
    // merge the states into the inputs (which is has one state per tick)
    const inputs = states.reduce((inputs, state, i) => {
        inputs.dungeonAttackArmour[i] = state.dungeonAttackArmour;
        inputs.dungeonAttackHealth[i] = state.dungeonAttackHealth;
        inputs.seekerAttackArmour[i] = state.seekerAttackArmour;
        inputs.seekerAttackHealth[i] = state.seekerAttackHealth;
        return inputs;
    }, {
        dungeonAttackArmour: Array(numTicks).fill(states[states.length-1].dungeonAttackArmour),
        dungeonAttackHealth: Array(numTicks).fill(states[states.length-1].dungeonAttackHealth),
        seekerAttackArmour: Array(numTicks).fill(states[states.length-1].seekerAttackArmour),
        seekerAttackHealth: Array(numTicks).fill(states[states.length-1].seekerAttackHealth),
        seekerSlot: 0,
    });

    // hash input values
    // structure of inputValues must match
    // input signals of the inputValuesHasher in combat.circom
    const poseidon = await circom.buildPoseidon();
    inputs.seekerValuesHash = [];
    for (let i=0; i<numSeekers; i++) {
        let inputValuesHash = 0;
        for (let t=numTicks-1; t>=0; t--) {
            inputValuesHash = poseidon([
                inputValuesHash,
                inputs.dungeonAttackArmour[t][i],
                inputs.dungeonAttackHealth[t][i],
                inputs.seekerAttackArmour[t][i],
                inputs.seekerAttackHealth[t][i],
            ]);
        }
        inputs.seekerValuesHash.push( poseidon.F.toString(inputValuesHash) );
    }

    return inputs;
}

main2()
    .then((data) => console.log(JSON.stringify(data)));


