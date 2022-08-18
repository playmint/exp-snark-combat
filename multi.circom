pragma circom 2.0.0;

include "comparators.circom";
include "gates.circom";

template Sum(n) {
    signal input in[n];
    signal output out;
    signal sums[n];

    sums[0] <== in[0];
    for (var i=1; i<n; i++) {
        sums[i] <== sums[i-1] + in[i];
    }

    out <== sums[n-1];
}

template Tick(numSeekers) {
    signal input seekerAttackArmour[numSeekers];
    signal input seekerAttackHealth[numSeekers];
    signal input dungeonAttackArmour[numSeekers];
    signal input dungeonAttackHealth[numSeekers];

    signal input prevDungeonArmour;
    signal input prevDungeonHealth;
    signal input prevSeekerArmour[numSeekers];
    signal input prevSeekerHealth[numSeekers];

    signal output nextDungeonArmour;
    signal output nextDungeonHealth;
    signal output nextSeekerArmour[numSeekers];
    signal output nextSeekerHealth[numSeekers];

	component seekerHealthOk[numSeekers];
	component seekerArmourFail[numSeekers];
	component dungeonHealthOk;
	component dungeonArmourFail;
	component dungeonHealthOkAndSeekerArmourFail[numSeekers];
	component seekerHealthOkAndDungeonArmourFail[numSeekers];
	component seekerHitpointsArmour;
	component seekerHitpointsHealth;

	dungeonHealthOk = GreaterThan(64); // [!]: why 64bit? 256bit?
	dungeonHealthOk.in[0] <== prevDungeonHealth;
	dungeonHealthOk.in[1] <== 0;

	dungeonArmourFail = IsZero();
	dungeonArmourFail.in <== prevDungeonArmour;

	seekerHitpointsArmour = Sum(numSeekers);
	seekerHitpointsHealth = Sum(numSeekers);

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

		// TODO: only attack every block % dex == 0
		// TODO: health regen every block % vitality ?

		nextSeekerArmour[i] <== prevSeekerArmour[i] - (dungeonHealthOk.out * dungeonAttackArmour[i]);
		nextSeekerHealth[i] <== prevSeekerHealth[i] - (dungeonHealthOkAndSeekerArmourFail[i].out * dungeonAttackHealth[i]);

		seekerHitpointsArmour.in[i] <== seekerHealthOk[i].out * seekerAttackArmour[i];
		seekerHitpointsHealth.in[i] <== seekerHealthOkAndDungeonArmourFail[i].out * seekerAttackHealth[i];
	}

	nextDungeonArmour <== prevDungeonArmour - seekerHitpointsArmour.out;
	nextDungeonHealth <== prevDungeonHealth - seekerHitpointsHealth.out;

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

	// public ending health values
	signal output dungeonArmourOut;
	signal output dungeonHealthOut;
	signal output seekerHealthOut[numSeekers];
	signal output seekerArmourOut[numSeekers];

	component tick[numTicks];

	// wireup t=0 (transition between current healths -> first tick)
	tick[0] = Tick(numSeekers);
	dungeonArmourIn ==> tick[0].prevDungeonArmour;
	dungeonHealthIn ==> tick[0].prevDungeonHealth;
	for(var i=0; i<numSeekers; i++){
		seekerAttackArmour[i] ==> tick[0].seekerAttackArmour[i];
		seekerAttackHealth[i] ==> tick[0].seekerAttackHealth[i];
		dungeonAttackArmour[i] ==> tick[0].dungeonAttackArmour[i];
		dungeonAttackHealth[i] ==> tick[0].dungeonAttackHealth[i];
		seekerArmourIn[i] ==> tick[0].prevSeekerArmour[i];
		seekerHealthIn[i] ==> tick[0].prevSeekerHealth[i];
	}

	// wireup t=1+ (transitions between ticks)
	for(var t=1; t<numTicks; t++){
		tick[t] = Tick(numSeekers);
		tick[t-1].nextDungeonArmour ==> tick[t].prevDungeonArmour;
		tick[t-1].nextDungeonHealth ==> tick[t].prevDungeonHealth;
		for(var i=0; i<numSeekers; i++){
			seekerAttackArmour[i] ==> tick[t].seekerAttackArmour[i];
			seekerAttackHealth[i] ==> tick[t].seekerAttackHealth[i];
			dungeonAttackArmour[i] ==> tick[t].dungeonAttackArmour[i];
			dungeonAttackHealth[i] ==> tick[t].dungeonAttackHealth[i];
			tick[t-1].nextSeekerArmour[i] ==> tick[t].prevSeekerArmour[i];
			tick[t-1].nextSeekerHealth[i] ==> tick[t].prevSeekerHealth[i];
		}
	}

	// expose the last tick's values as public output signals
	dungeonArmourOut <== tick[numTicks-1].nextDungeonArmour;
	dungeonHealthOut <== tick[numTicks-1].nextDungeonHealth;
	for(var i=0; i<numSeekers; i++){
		seekerHealthOut[i] <== tick[numTicks-1].nextSeekerHealth[i];
		seekerArmourOut[i] <== tick[numTicks-1].nextSeekerArmour[i];
	}

	// TODO: can we set the outputs to a specific "tick" ie "dungeon health at the fifth tick"?
	// this would allow us to have a big tick-cap, but verify from a subset of it
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
} = Combat(5, 3);
