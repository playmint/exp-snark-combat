pragma circom 2.0.0;

include "comparators.circom";
include "gates.circom";
include "mimcsponge.circom";
include "poseidon.circom";

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
// idx[0] selects the 1st dim
// idx[1] selects the 2nd dim
template Select2(n, x) {
	signal input in[n][x];
	signal input idx[2];
	signal output out;
	component sel = Select(x);
	component iseq[n];
	component sm[x];

	for (var j=0; j<x; j++) {
		sm[j] = Sum(n);
	}

	for (var i=0; i<n; i++) {
		iseq[i] = IsEqual();
		iseq[i].in[0] <== i;
		iseq[i].in[1] <== idx[0];
		for (var j=0; j<x; j++) {
			sm[j].in[i] <== (iseq[i].out * in[i][j]);
		}
	}

	for (var j=0; j<x; j++) {
		sel.in[j] <== sm[j].out;
	}
	sel.idx <== idx[1];
	out <== sel.out;
}

// same as Select but output is an array of X signals
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

	component nextDungeonArmourSub = ClampedSub(16);
	component nextDungeonHealthSub = ClampedSub(16);
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

		// TODO: add back these bits
		// TODO: only attack every block % dex == 0
		// TODO: health regen every block % vitality ?

		nextSeekerArmourSub[i] = ClampedSub(16);
		nextSeekerArmourSub[i].a <== prevSeekerArmour[i];
		nextSeekerArmourSub[i].b <== (dungeonHealthOk.out * dungeonAttackArmour[i]);
		nextSeekerArmour[i] <== nextSeekerArmourSub[i].out;

		nextSeekerHealthSub[i] = ClampedSub(16);
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

template CombatStateHash(numSeekers) {
	signal input dungeonArmour;
	signal input dungeonHealth;
	signal input seekerArmour[numSeekers];
	signal input seekerHealth[numSeekers];
	signal output out;

	component inputValuesHash = MiMCSponge((numSeekers*2)+2, 220, 1);
	inputValuesHash.k <== 0;
	inputValuesHash.ins[0] <== dungeonArmour;
	inputValuesHash.ins[1] <== dungeonHealth;
	for(var i=0; i<numSeekers; i++){
		inputValuesHash.ins[(i*2)+2] <== seekerArmour[i];
		inputValuesHash.ins[(i*2)+3] <== seekerHealth[i];
	}
	out <== inputValuesHash.outs[0];
}

template SelectAction(n, numOutputs) {
	signal input dungeonAttackArmourIn[n][numOutputs];
	signal input dungeonAttackHealthIn[n][numOutputs];
	signal input seekerAttackArmourIn[n][numOutputs];
	signal input seekerAttackHealthIn[n][numOutputs];
	signal input tick;
	signal input after[n];
	signal output dungeonAttackArmourOut[numOutputs];
	signal output dungeonAttackHealthOut[numOutputs];
	signal output seekerAttackArmourOut[numOutputs];
	signal output seekerAttackHealthOut[numOutputs];


	component a[n];
	component b[n];
	component and[n];
	component dungeonAttackArmourSum[numOutputs];
	component dungeonAttackHealthSum[numOutputs];
	component seekerAttackArmourSum[numOutputs];
	component seekerAttackHealthSum[numOutputs];

	for (var j=0; j<numOutputs; j++) {
		dungeonAttackArmourSum[j] = Sum(n);
		dungeonAttackHealthSum[j] = Sum(n);
		seekerAttackArmourSum[j] = Sum(n);
		seekerAttackHealthSum[j] = Sum(n);
	}

	for (var i=0; i<n; i++) {
		// [0] < [1]
		a[i] = GreaterEqThan(16);
		a[i].in[0] <== tick;
		a[i].in[1] <== after[i];

		b[i] = GreaterThan(16);
		b[i].in[0] <== i == n-1 ? 9999 : after[i+1];
		b[i].in[1] <== tick;

		and[i] = AND();
		and[i].a <== a[i].out;
		and[i].b <== b[i].out;

		for (var j=0; j<numOutputs; j++) {
			dungeonAttackArmourSum[j].in[i] <== (and[i].out * dungeonAttackArmourIn[i][j]);
			dungeonAttackHealthSum[j].in[i] <== (and[i].out * dungeonAttackHealthIn[i][j]);
			seekerAttackArmourSum[j].in[i] <== (and[i].out * seekerAttackArmourIn[i][j]);
			seekerAttackHealthSum[j].in[i] <== (and[i].out * seekerAttackHealthIn[i][j]);
		}
	}

	for (var j=0; j<numOutputs; j++) {
		dungeonAttackArmourOut[j] <== dungeonAttackArmourSum[j].out;
		dungeonAttackHealthOut[j] <== dungeonAttackHealthSum[j].out;
		seekerAttackArmourOut[j] <== seekerAttackArmourSum[j].out;
		seekerAttackHealthOut[j] <== seekerAttackHealthSum[j].out;
	}
}

template Combat(numSeekers, numTicks) {
	signal input dungeonAttackArmour[numTicks][numSeekers];
	signal input dungeonAttackHealth[numTicks][numSeekers];
	signal input seekerAttackArmour[numTicks][numSeekers];
	signal input seekerAttackHealth[numTicks][numSeekers];
	signal input seekerValuesHash[numSeekers];
	signal input seekerValuesUpdated[numTicks][numSeekers];

	// currentSeeker indicates which seeker data
	// we will be building a proof for
	signal input currentSeeker;

	// currentTick indicates which tick we are outputting health values for
	signal input currentTick;

	signal output dungeonArmourFinal;
	signal output dungeonHealthFinal;
	signal output seekerArmourFinal;
	signal output seekerHealthFinal;

	// check that the given seekerValuesHashes match the given attack values
	component seekerValuesHashSum[numTicks*numSeekers];
	signal seekerValuesHashCalc[numTicks*numSeekers];
	signal seekerValuesHashPrev[numTicks*numSeekers];
	component seekerValuesHasher[numTicks*numSeekers];
	component seekerValuesIsNotUpdate[numTicks*numSeekers];
	signal prevDungeonAttackArmour[numTicks*numSeekers];
	signal prevDungeonAttackHealth[numTicks*numSeekers];
	signal prevSeekerAttackArmour[numTicks*numSeekers];
	signal prevSeekerAttackHealth[numTicks*numSeekers];
	var h = 0;
	for(var i=0; i<numSeekers; i++){
		for(var t=0; t<numTicks; t++){
			// keep track of the prev hash value or default to 0
			seekerValuesHashPrev[h] <== t==0 == 1 ? 0 : seekerValuesHashCalc[h-1];
			// hash the prev value + this tick's values
			seekerValuesHasher[h] = Poseidon(6);
			seekerValuesHasher[h].inputs[0] <== seekerValuesHashPrev[h];
			seekerValuesHasher[h].inputs[1] <== dungeonAttackArmour[t][i];
			seekerValuesHasher[h].inputs[2] <== dungeonAttackHealth[t][i];
			seekerValuesHasher[h].inputs[3] <== seekerAttackArmour[t][i];
			seekerValuesHasher[h].inputs[4] <== seekerAttackHealth[t][i];
			seekerValuesHasher[h].inputs[5] <== t;
			// only include the hash of this tick's values in the final seeker hash if
			// this tick has been marked as a tick where an action ocurred via the presence
			// of a "1" in the seekerValuesUpdated input for this tick
			seekerValuesIsNotUpdate[h] = IsZero();
			seekerValuesIsNotUpdate[h].in <== seekerValuesUpdated[t][i];
			seekerValuesHashSum[h] = Sum(2);
			seekerValuesHashSum[h].in[0] <== seekerValuesHashPrev[h] * seekerValuesIsNotUpdate[h].out;
			seekerValuesHashSum[h].in[1] <== seekerValuesHasher[h].out * (1-seekerValuesIsNotUpdate[h].out);
			seekerValuesHashCalc[h] <== seekerValuesHashSum[h].out;
			// ensure that if this is NOT an "action tick" then this tick's values
			// should be identical to the previous tick's values.
			// if we don't do this, then someone could spoof the input
			prevDungeonAttackArmour[h] <== t == 0 ? 0 : (dungeonAttackArmour[t-1][i] * seekerValuesIsNotUpdate[h].out);
			dungeonAttackArmour[t][i] * seekerValuesIsNotUpdate[h].out === prevDungeonAttackArmour[h];
			prevDungeonAttackHealth[h] <== t == 0 ? 0 : (dungeonAttackHealth[t-1][i] * seekerValuesIsNotUpdate[h].out);
			dungeonAttackHealth[t][i] * seekerValuesIsNotUpdate[h].out === prevDungeonAttackHealth[h];
			prevSeekerAttackArmour[h] <== t == 0 ? 0 : (seekerAttackArmour[t-1][i] * seekerValuesIsNotUpdate[h].out);
			seekerAttackArmour[t][i] * seekerValuesIsNotUpdate[h].out === prevSeekerAttackArmour[h];
			prevSeekerAttackHealth[h] <== t == 0 ? 0 : (seekerAttackHealth[t-1][i] * seekerValuesIsNotUpdate[h].out);
			seekerAttackHealth[t][i] * seekerValuesIsNotUpdate[h].out === prevSeekerAttackHealth[h];
			// inc
			h++;
		}
		seekerValuesHash[i] === seekerValuesHashCalc[h-1];
	}

	// for each tick, calculate the armour/health values
	component tick[numTicks];
	for(var t=0; t<numTicks; t++){
		tick[t] = Tick(numSeekers);
		tick[t].prevDungeonArmour <== t == 0 ? 100 : tick[t-1].nextDungeonArmour;
		tick[t].prevDungeonHealth <== t == 0 ? 100 : tick[t-1].nextDungeonHealth;
		for(var i=0; i<numSeekers; i++){
			tick[t].dungeonAttackArmour[i] <== dungeonAttackArmour[t][i];
			tick[t].dungeonAttackHealth[i] <== dungeonAttackHealth[t][i];
			tick[t].seekerAttackArmour[i] <== seekerAttackArmour[t][i];
			tick[t].seekerAttackHealth[i] <== seekerAttackHealth[t][i];
			tick[t].prevSeekerArmour[i] <== t == 0 ? 100 : tick[t-1].nextSeekerArmour[i];
			tick[t].prevSeekerHealth[i] <== t == 0 ? 100 : tick[t-1].nextSeekerHealth[i];
		}
	}

	// pick which tick we output the values for
	component selectedDungeonArmourTick = Select(numTicks);
	component selectedDungeonHealthTick = Select(numTicks);
	component selectedSeekerArmourTick = Select2(numTicks, numSeekers);
	component selectedSeekerHealthTick = Select2(numTicks, numSeekers);
	for(var i=0; i<numTicks; i++){
		selectedDungeonArmourTick.in[i] <== tick[i].nextDungeonArmour;
		selectedDungeonHealthTick.in[i] <== tick[i].nextDungeonHealth;
		for(var j=0; j<numSeekers; j++){
			selectedSeekerArmourTick.in[i][j] <== tick[i].nextSeekerArmour[j];
			selectedSeekerHealthTick.in[i][j] <== tick[i].nextSeekerHealth[j];
		}
	}
	selectedDungeonArmourTick.idx <== currentTick;
	selectedDungeonHealthTick.idx <== currentTick;
	selectedSeekerArmourTick.idx[0] <== currentTick;
	selectedSeekerArmourTick.idx[1] <== currentSeeker;
	selectedSeekerHealthTick.idx[0] <== currentTick;
	selectedSeekerHealthTick.idx[1] <== currentSeeker;

	// output dungeon healths
	dungeonHealthFinal <== selectedDungeonHealthTick.out;
	dungeonArmourFinal <== selectedDungeonArmourTick.out;
	seekerArmourFinal <== selectedSeekerArmourTick.out;
	seekerHealthFinal <== selectedSeekerHealthTick.out;
}

 component main {
	public [
		seekerValuesHash,
		currentSeeker,
		currentTick
	]
} = Combat(3, 100);
