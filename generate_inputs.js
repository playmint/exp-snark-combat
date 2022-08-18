const args = process.argv.slice(2);

const numSeekers = parseInt(args[0], 10);

const seekerAttackArmour = 1;
const seekerAttackHealth = 1;

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

console.log(JSON.stringify(inputs,null,2));


