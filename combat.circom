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

// Given a list of N input signals and an index signal i, return the value of signal at inputs[i] as output
template Select(n) {
	signal input in[n];
	signal input idx;
	signal output out;
	component iseq[n];
	component sm = Sum(n);

	for (var i=0; i<n; i++) {
		iseq[i] = IsEqual();
		iseq[i].in[0] <== i;
		iseq[i].in[1] <== idx;
		sm.in[i] <== (iseq[i].out * in[i]);
	}

	out <== sm.out;
}

// same as Select, but each input is an array of X signals
template SelectArray(n, x) {
	signal input in[n][x];
	signal input idx;
	signal output out[x];
	component iseq[n];
	component sm[x];

	for (var j=0; j<x; j++) {
		sm[j] = Sum(n);
	}

	for (var i=0; i<n; i++) {
		iseq[i] = IsEqual();
		iseq[i].in[0] <== i;
		iseq[i].in[1] <== idx;
		for (var j=0; j<x; j++) {
			sm[j].in[i] <== (iseq[i].out * in[i][j]);
		}
	}

	for (var j=0; j<x; j++) {
		out[j] <== sm[j].out;
	}
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

	signal input selectedTick;

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

	component selectedDungeonArmour = Select(numTicks);
	component selectedDungeonHealth = Select(numTicks);
	component selectedSeekerArmour = SelectArray(numTicks, numSeekers);
	component selectedSeekerHealth = SelectArray(numTicks, numSeekers);

	selectedDungeonArmour.idx <== selectedTick;
	selectedDungeonHealth.idx <== selectedTick;
	selectedSeekerArmour.idx <== selectedTick;
	selectedSeekerHealth.idx <== selectedTick;

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

	// expose the selected tick's health values as public output signals
	for(var t=0; t<numTicks; t++){
		selectedDungeonArmour.in[t] <== tick[t].nextDungeonArmour;
		selectedDungeonHealth.in[t] <== tick[t].nextDungeonHealth;
		for(var i=0; i<numSeekers; i++){
			selectedSeekerArmour.in[t][i] <== tick[t].nextSeekerArmour[i];
			selectedSeekerHealth.in[t][i] <== tick[t].nextSeekerHealth[i];
		}
	}
	dungeonArmourOut <== selectedDungeonArmour.out;
	dungeonHealthOut <== selectedDungeonHealth.out;
	component iseq[numSeekers];
	component sm = Sum(numSeekers);
	for(var i=0; i<numSeekers; i++){
		seekerArmourOut[i] <== selectedSeekerArmour.out[i];
		seekerHealthOut[i] <== selectedSeekerHealth.out[i];
	}

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
} = Combat(5, 10000);
