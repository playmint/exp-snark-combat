pragma circom 2.0.0;

include "comparators.circom";
include "gates.circom";

template Tick(numSeekers) {
    signal input seekerAttackArmour[numSeekers];
    signal input seekerAttackHealth[numSeekers];
    signal input dungeonAttackArmour[numSeekers];
    signal input dungeonAttackHealth[numSeekers];

    signal input prevDungeonArmour;
    signal input prevDungeonHealth;
    signal input prevSeekerArmour[numSeekers];
    signal input prevSeekerHealth[numSeekers];

    signal input nextDungeonArmour;
    signal input nextDungeonHealth;
    signal input nextSeekerArmour[numSeekers];
    signal input nextSeekerHealth[numSeekers];

	component seekerHealthOk[numSeekers];
	component seekerArmourFail[numSeekers];
	component dungeonHealthOk;
	component dungeonArmourFail;
	component dungeonHealthOkAndSeekerArmourFail[numSeekers];
	component seekerHealthOkAndDungeonArmourFail[numSeekers];

	dungeonHealthOk = GreaterThan(64); // [!]: why 64bit? 256bit?
	dungeonHealthOk.in[0] <== prevDungeonHealth;
	dungeonHealthOk.in[1] <== 0;

	dungeonArmourFail = IsZero(); // [!]: why 64bit?
	dungeonArmourFail.in <== prevDungeonArmour;

	signal seekerHitpointsArmour[numSeekers];
	signal seekerTotalArmour[numSeekers+1];
	signal seekerHitpointsHealth[numSeekers];
	signal seekerTotalHealth[numSeekers+1];

	for(var i=0; i<numSeekers; i++){
		seekerHealthOk[i] = GreaterThan(64); // 64bit? 256bit?
		seekerHealthOk[i].in[0] <== prevSeekerHealth[i];
		seekerHealthOk[i].in[1] <== 0;

		seekerArmourFail[i] = IsZero();
		seekerArmourFail[i].in <== prevSeekerArmour[i];

		dungeonHealthOkAndSeekerArmourFail[i] = AND();
		dungeonHealthOkAndSeekerArmourFail[i].a <== dungeonHealthOk.out;
		dungeonHealthOkAndSeekerArmourFail[i].b <== seekerArmourFail[i].out;

		seekerHealthOkAndDungeonArmourFail[i] = AND();
		seekerHealthOkAndDungeonArmourFail[i].a <== seekerHealthOk[i].out;
		seekerHealthOkAndDungeonArmourFail[i].b <== dungeonArmourFail.out;

		nextSeekerArmour[i] === prevSeekerArmour[i] - (dungeonHealthOk.out * dungeonAttackArmour[i]);
		nextSeekerHealth[i] === prevSeekerHealth[i] - (dungeonHealthOkAndSeekerArmourFail[i].out * dungeonAttackHealth[i]);

		seekerHitpointsArmour[i] <== seekerHealthOk[i].out * seekerAttackArmour[i];
		seekerHitpointsHealth[i] <== seekerHealthOkAndDungeonArmourFail[i].out * seekerAttackHealth[i];
	}

	// [!]: there must be a better way to sum than this mess?!
	seekerTotalArmour[0] <== 0;
	seekerTotalHealth[0] <== 0;
	for(var i=0; i<numSeekers; i++){
		seekerTotalArmour[i+1] <== seekerTotalArmour[i] + seekerHitpointsArmour[i];
		seekerTotalHealth[i+1] <== seekerTotalHealth[i] + seekerHitpointsHealth[i];
	}
	nextDungeonArmour === prevDungeonArmour - seekerTotalArmour[numSeekers];
	nextDungeonHealth === prevDungeonHealth - seekerTotalHealth[numSeekers];

}

template Combat(numSeekers, numTicks) {

	// public starting health values
	signal input dungeonArmourIn;
	signal input dungeonHealthIn;
	signal input seekerHealthIn[numSeekers];
	signal input seekerArmourIn[numSeekers];

	// public stats values
    signal input seekerAttackArmour[numSeekers];
    signal input seekerAttackHealth[numSeekers];
    signal input dungeonAttackArmour[numSeekers];
    signal input dungeonAttackHealth[numSeekers];

	// private execution trace
    signal input dungeonArmour[numTicks];
    signal input dungeonHealth[numTicks];
    signal input seekerArmour[numTicks][numSeekers];
    signal input seekerHealth[numTicks][numSeekers];

	// public ending health values
	signal output dungeonArmourOut;
	signal output dungeonHealthOut;
	signal output seekerHealthOut[numSeekers];
	signal output seekerArmourOut[numSeekers];

	component tick[numTicks];

	// wireup t=0 (transition between current healths -> first tick)
	tick[0] = Tick(numSeekers);
	dungeonArmourIn ==> tick[0].prevDungeonArmour;
	dungeonArmour[0] ==> tick[0].nextDungeonArmour;
	dungeonHealthIn ==> tick[0].prevDungeonHealth;
	dungeonHealth[0] ==> tick[0].nextDungeonHealth;
	for(var i=0; i<numSeekers; i++){
		seekerAttackArmour[i] ==> tick[0].seekerAttackArmour[i];
		seekerAttackHealth[i] ==> tick[0].seekerAttackHealth[i];
		dungeonAttackArmour[i] ==> tick[0].dungeonAttackArmour[i];
		dungeonAttackHealth[i] ==> tick[0].dungeonAttackHealth[i];
		seekerArmourIn[i] ==> tick[0].prevSeekerArmour[i];
		seekerArmour[0][i] ==> tick[0].nextSeekerArmour[i];
		seekerHealthIn[i] ==> tick[0].prevSeekerHealth[i];
		seekerHealth[0][i] ==> tick[0].nextSeekerHealth[i];
	}

	// wireup t=1+ (transitions between ticks)
	for(var t=1; t<numTicks; t++){
		tick[t] = Tick(numSeekers);
		dungeonArmour[t-1] ==> tick[t].prevDungeonArmour;
		dungeonArmour[t] ==> tick[t].nextDungeonArmour;
		dungeonHealth[t-1] ==> tick[t].prevDungeonHealth;
		dungeonHealth[t] ==> tick[t].nextDungeonHealth;
		for(var i=0; i<numSeekers; i++){
			seekerAttackArmour[i] ==> tick[t].seekerAttackArmour[i];
			seekerAttackHealth[i] ==> tick[t].seekerAttackHealth[i];
			dungeonAttackArmour[i] ==> tick[t].dungeonAttackArmour[i];
			dungeonAttackHealth[i] ==> tick[t].dungeonAttackHealth[i];
			seekerArmour[t-1][i] ==> tick[t].prevSeekerArmour[i];
			seekerArmour[t][i] ==> tick[t].nextSeekerArmour[i];
			seekerHealth[t-1][i] ==> tick[t].prevSeekerHealth[i];
			seekerHealth[t][i] ==> tick[t].nextSeekerHealth[i];
		}
	}

	// expose the last tick's values as public signals
	dungeonArmourOut <== tick[numTicks-1].nextDungeonArmour;
	dungeonHealthOut <== tick[numTicks-1].nextDungeonHealth;
	for(var i=0; i<numSeekers; i++){
		seekerHealthOut[i] <== tick[numTicks-1].nextSeekerHealth[i];
		seekerArmourOut[i] <== tick[numTicks-1].nextSeekerArmour[i];
	}

	// out should be a specific tick from the "trace" ie "dungeon health at the fifth tick" to allow commiting to a current block
 }

 component main {
	public [
		dungeonArmourIn,
		dungeonHealthIn,
		seekerArmourIn,
		seekerHealthIn,
		seekerAttackArmour,
		seekerAttackHealth,
		dungeonAttackArmour,
		dungeonAttackHealth
	]
} = Combat(3, 3);
