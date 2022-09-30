const circom = require('circomlibjs');


async function main() {
    const SEED = "mimcsponge";
    const bytes = await circom.poseidonContract.createCode(2);
    return bytes;
}

main()
    .then((data) => process.stdout.write(data));


