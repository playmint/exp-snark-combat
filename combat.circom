pragma circom 2.0.0;

include "comparators.circom";
include "gates.circom";
include "mimcsponge.circom";

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

template IsNotZero() {
	signal input in;
	signal output out;

	component isz = IsZero();
	component not = NOT();

	in ==> isz.in;
	isz.out ==> not.in;
	out <== not.out;
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

template TickHadNoEffect(numSeekers) {
    signal input prevDungeonArmour;
    signal input prevDungeonHealth;
    signal input prevSeekerArmour[numSeekers];
    signal input prevSeekerHealth[numSeekers];

    signal input nextDungeonArmour;
    signal input nextDungeonHealth;
    signal input nextSeekerArmour[numSeekers];
    signal input nextSeekerHealth[numSeekers];

	signal output out;

	component pairs[2+(numSeekers*2)];
	component all = MultiAND(2+(numSeekers*2));

	for (var i=0; i<(2+(numSeekers*2)); i++) {
		pairs[i] = IsEqual();
	}

	pairs[0].in[0] <== prevDungeonArmour;
	pairs[0].in[1] <== nextDungeonArmour;

	pairs[1].in[0] <== prevDungeonHealth;
	pairs[1].in[1] <== nextDungeonHealth;

	for(var i=0; i<numSeekers; i++){
		pairs[(i*2)+2].in[0] <== prevSeekerArmour[i];
		pairs[(i*2)+2].in[1] <== nextSeekerArmour[i];

		pairs[(i*2)+3].in[0] <== prevSeekerHealth[i];
		pairs[(i*2)+3].in[1] <== nextSeekerHealth[i];
	}

	for(var i=0; i<(2+(numSeekers*2)); i++){
		all.in[i] <== pairs[i].out;
	}

	out <== all.out;
}

template TicksHadNoEffect(n, numSeekers) {
    signal input prevDungeonArmour[n];
    signal input prevDungeonHealth[n];
    signal input prevSeekerArmour[n][numSeekers];
    signal input prevSeekerHealth[n][numSeekers];

    signal input nextDungeonArmour[n];
    signal input nextDungeonHealth[n];
    signal input nextSeekerArmour[n][numSeekers];
    signal input nextSeekerHealth[n][numSeekers];

	signal output out;

	component noeff[n];
	component all = MultiAND(n);

	for (var t=0; t<n; t++) {
		noeff[t] = TickHadNoEffect(numSeekers);
		noeff[t].prevDungeonArmour <== prevDungeonArmour[t];
		noeff[t].nextDungeonArmour <== nextDungeonHealth[t];
		noeff[t].prevDungeonHealth <== prevDungeonHealth[t];
		noeff[t].nextDungeonHealth <== nextDungeonHealth[t];
		for(var i=0; i<numSeekers; i++){
			noeff[t].prevSeekerArmour[i] <== prevSeekerArmour[t][i];
			noeff[t].nextSeekerArmour[i] <== nextSeekerArmour[t][i];
			noeff[t].prevSeekerHealth[i] <== prevSeekerHealth[t][i];
			noeff[t].nextSeekerHealth[i] <== nextSeekerHealth[t][i];
		}
		all.in[t] <== noeff[t].out;
	}

	out <== all.out;
}

// subtract b from a, but prevent going below zero
template ClampedSub(nbits) {
	signal input a;
	signal input b;
	signal output out;

	// is b < a+1
	component lt = LessThan(nbits);
	lt.in[0] <== b;
	lt.in[1] <== a+1;

	// if so clamp to zero else perfrom the sub
	out <== lt.out * (a - b);
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

	component nextDungeonArmourSub = ClampedSub(8);
	component nextDungeonHealthSub = ClampedSub(8);
	component nextSeekerArmourSub[numSeekers];
	component nextSeekerHealthSub[numSeekers];

	component seekerHealthOk[numSeekers];
	component seekerArmourFail[numSeekers];
	component dungeonHealthOk;
	component dungeonArmourFail;
	component dungeonHealthOkAndSeekerArmourFail[numSeekers];
	component seekerHealthOkAndDungeonArmourFail[numSeekers];
	component seekerHitpointsArmour;
	component seekerHitpointsHealth;

	dungeonHealthOk = IsNotZero();
	dungeonHealthOk.in <== prevDungeonHealth;

	dungeonArmourFail = IsZero();
	dungeonArmourFail.in <== prevDungeonArmour;

	seekerHitpointsArmour = Sum(numSeekers);
	seekerHitpointsHealth = Sum(numSeekers);

	for(var i=0; i<numSeekers; i++){
		seekerHealthOk[i] = IsNotZero();
		seekerHealthOk[i].in <== prevSeekerHealth[i];

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

		nextSeekerArmourSub[i] = ClampedSub(8);
		nextSeekerArmourSub[i].a <== prevSeekerArmour[i];
		nextSeekerArmourSub[i].b <== (dungeonHealthOk.out * dungeonAttackArmour[i]);
		nextSeekerArmour[i] <== nextSeekerArmourSub[i].out;

		nextSeekerHealthSub[i] = ClampedSub(8);
		nextSeekerHealthSub[i].a <== prevSeekerHealth[i];
		nextSeekerHealthSub[i].b <== (dungeonHealthOkAndSeekerArmourFail[i].out * dungeonAttackHealth[i]);
		nextSeekerHealth[i] <== nextSeekerHealthSub[i].out;

		seekerHitpointsArmour.in[i] <== seekerHealthOk[i].out * seekerAttackArmour[i];
		seekerHitpointsHealth.in[i] <== seekerHealthOkAndDungeonArmourFail[i].out * seekerAttackHealth[i];
	}

	nextDungeonArmourSub.a <== prevDungeonArmour;
	nextDungeonArmourSub.b <== seekerHitpointsArmour.out;
	nextDungeonArmour <== nextDungeonArmourSub.out;

	nextDungeonHealthSub.a <== prevDungeonHealth;
	nextDungeonHealthSub.b <== seekerHitpointsHealth.out;
	nextDungeonHealth <== nextDungeonHealthSub.out;

}

template Combat(numSeekers, numTicks) {

	signal input selectedTick;

	// public starting health value hash
	signal input hashIn;

	// private state values
	signal input dungeonArmourIn;
	signal input dungeonHealthIn;
	signal input seekerHealthIn[numSeekers];
	signal input seekerArmourIn[numSeekers];
    signal input seekerAttackArmour[numSeekers];
    signal input seekerAttackHealth[numSeekers];
    signal input dungeonAttackArmour[numSeekers];
    signal input dungeonAttackHealth[numSeekers];

	// public ending state values
	signal output dungeonArmourOut;
	signal output dungeonHealthOut;
	signal output seekerHealthOut[numSeekers];
	signal output seekerArmourOut[numSeekers];
	signal output hashOut;
	signal output steadyState;

	// TODO: template this because we use it twice
	// verify that the input values hash matches the input values
	component inputValuesHash = MiMCSponge((numSeekers*6)+2, 220, 1);
	inputValuesHash.k <== 0;
	inputValuesHash.ins[0] <== dungeonArmourIn;
	inputValuesHash.ins[1] <== dungeonHealthIn;
	for(var i=0; i<numSeekers; i++){
		inputValuesHash.ins[(i*6)+2] <== seekerArmourIn[i];
		inputValuesHash.ins[(i*6)+3] <== seekerHealthIn[i];
		inputValuesHash.ins[(i*6)+4] <== seekerAttackArmour[i];
		inputValuesHash.ins[(i*6)+5] <== seekerAttackHealth[i];
		inputValuesHash.ins[(i*6)+6] <== dungeonAttackArmour[i];
		inputValuesHash.ins[(i*6)+7] <== dungeonAttackHealth[i];
	}
	hashIn === inputValuesHash.outs[0];


	component tick[numTicks];

	component selectedDungeonArmour = Select(numTicks);
	component selectedDungeonHealth = Select(numTicks);
	component selectedSeekerArmour = SelectArray(numTicks, numSeekers);
	component selectedSeekerHealth = SelectArray(numTicks, numSeekers);

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
	selectedDungeonArmour.idx <== selectedTick;
	selectedDungeonHealth.idx <== selectedTick;
	selectedSeekerArmour.idx <== selectedTick;
	selectedSeekerHealth.idx <== selectedTick;
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

	// build n verify hash of selected tick's health values as public output
	component selectedValuesHash = MiMCSponge((numSeekers*6)+2, 220, 1);
	selectedValuesHash.k <== 0;
	selectedValuesHash.ins[0] <== dungeonArmourOut;
	selectedValuesHash.ins[1] <== dungeonHealthOut;
	for(var i=0; i<numSeekers; i++){
		selectedValuesHash.ins[(i*6)+2] <== seekerArmourOut[i];
		selectedValuesHash.ins[(i*6)+3] <== seekerHealthOut[i];
		selectedValuesHash.ins[(i*6)+4] <== seekerAttackArmour[i];
		selectedValuesHash.ins[(i*6)+5] <== seekerAttackHealth[i];
		selectedValuesHash.ins[(i*6)+6] <== dungeonAttackArmour[i];
		selectedValuesHash.ins[(i*6)+7] <== dungeonAttackHealth[i];
	}
	hashOut <== selectedValuesHash.outs[0];

	// expose if combat has reached an equilibrium
	// ie. all ticks for any future proofs will have the same values
	// we can use this fact later to skip over large periods of
	// inactivity where no changes have occured
	// ---
	// combat is considered at equilibrium if all the values are unchanged
	// over the last N ticks ... where N is the largest dexterity or vitality number
	// (since those values affect _which_ tick triggers their action for example health
	// regens on `tick % 3 == 0` so we need to see at least 3 ticks unchanged)
	component isEquilibrium = TicksHadNoEffect(4, numSeekers);
	for (var t=0; t<4; t++) {
		isEquilibrium.prevDungeonArmour[t] <== tick[numTicks-1-t].prevDungeonArmour;
		isEquilibrium.nextDungeonArmour[t] <== tick[numTicks-1-t].nextDungeonArmour;
		isEquilibrium.prevDungeonHealth[t] <== tick[numTicks-1-t].prevDungeonHealth;
		isEquilibrium.nextDungeonHealth[t] <== tick[numTicks-1-t].nextDungeonHealth;
		for(var i=0; i<numSeekers; i++){
			isEquilibrium.prevSeekerArmour[t][i] <== tick[numTicks-1-t].prevSeekerArmour[i];
			isEquilibrium.nextSeekerArmour[t][i] <== tick[numTicks-1-t].nextSeekerArmour[i];
			isEquilibrium.prevSeekerHealth[t][i] <== tick[numTicks-1-t].prevSeekerHealth[i];
			isEquilibrium.nextSeekerHealth[t][i] <== tick[numTicks-1-t].nextSeekerHealth[i];
		}
	}
	steadyState <== isEquilibrium.out;


 }

 component main {
	public [
		hashIn
	]
} = Combat(5, 100);
