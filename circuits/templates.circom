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

template PackSlotConfig() {
	signal input in[5];
	signal output out;

	// FIXME: THIS IS NOT SECURE, just wanted to get it working
	out <-- 0
	| (in[0] << 8)
	| (in[1] << 21)
	| (in[2] << 34)
	| (in[3] << 47)
	| (in[4] << 60);
}

template Tick(numSeekers) {
    signal input seekerHRV[numSeekers];
    signal input seekerYLB[numSeekers];
    signal input seekerEND[numSeekers];
    signal input seekerACT[numSeekers];

    signal input prevYield[numSeekers];
    signal output nextYield[numSeekers];

	// TODO: theres more to it than that!
	for(var i=0; i<numSeekers; i++){
		nextYield[i] <== prevYield[i] + seekerHRV[i];
	}
}

template CombatNoHash(numSeekers, numTicks) {
	signal input seekerHRV[numTicks][numSeekers]; // standard rate
	signal input seekerYLB[numTicks][numSeekers]; // potential bonus
	signal input seekerEND[numTicks][numSeekers]; // health mod (only for certain ACT)
	signal input seekerACT[numTicks][numSeekers]; // action type JOIN/LEAVE/EQUIP etc

	// currentTick indicates which tick we are outputting health values for
	signal input currentTick;

	// yields is the yield output per seeker for the currentTick
	signal output yields[numSeekers];

	// for each tick, calculate the armour/health values
	component tick[numTicks];
	for(var t=0; t<numTicks; t++){
		tick[t] = Tick(numSeekers);
		for(var i=0; i<numSeekers; i++){
			tick[t].seekerHRV[i] <== seekerHRV[t][i];
			tick[t].seekerYLB[i] <== seekerYLB[t][i];
			tick[t].seekerEND[i] <== seekerEND[t][i];
			tick[t].seekerACT[i] <== seekerACT[t][i];
			tick[t].prevYield[i] <== t == 0 ? 100 : tick[t-1].nextYield[i];
		}
	}

	// pick which tick we output the values for
	component selectedSeekerYieldTick = SelectArray(numTicks, numSeekers);
	for(var i=0; i<numTicks; i++){
		for(var j=0; j<numSeekers; j++){
			selectedSeekerYieldTick.in[i][j] <== tick[i].nextYield[j];
		}
	}
	selectedSeekerYieldTick.idx <== currentTick;

	// output all seeker yields at currentTick
	for(var j=0; j<numSeekers; j++){
		yields[j] <== selectedSeekerYieldTick.out[j];
	}
}
template Combat(numSeekers, numTicks) {
	signal input seekerHRV[numTicks][numSeekers]; // standard rate
	signal input seekerYLB[numTicks][numSeekers]; // potential bonus
	signal input seekerEND[numTicks][numSeekers]; // health mod (only for certain ACT)
	signal input seekerACT[numTicks][numSeekers]; // action type JOIN/LEAVE/EQUIP etc
	signal input seekerValuesHash[numSeekers];
	signal input seekerValuesUpdated[numTicks][numSeekers];

	// currentTick indicates which tick we are outputting health values for
	signal input currentTick;

	// yields is the yield output per seeker for the currentTick
	signal output yields[numSeekers];

	// check that the given seekerValuesHashes match the given attack values
	component seekerValuesHashSum[numTicks*numSeekers];
	signal seekerValuesHashCalc[numTicks*numSeekers];
	signal seekerValuesHashPrev[numTicks*numSeekers];
	component seekerValuesHasher[numTicks*numSeekers];
	component seekerValuesIsNotUpdate[numTicks*numSeekers];
	signal prevSeekerHRV[numTicks*numSeekers];
	signal prevSeekerYLB[numTicks*numSeekers];
	signal prevSeekerEND[numTicks*numSeekers];
	signal prevSeekerACT[numTicks*numSeekers];
	component packedSlotConfig[numTicks*numSeekers];
	var h = 0;
	for(var i=0; i<numSeekers; i++){
		for(var t=0; t<numTicks; t++){
			// keep track of the prev hash value or default to 0
			seekerValuesHashPrev[h] <== t==0 == 1 ? 0 : seekerValuesHashCalc[h-1];
			// pack all the values together as per packSlotConfig in contract
			packedSlotConfig[h] = PackSlotConfig();
			packedSlotConfig[h].in[0] <== seekerACT[t][i];
			packedSlotConfig[h].in[1] <== t;
			packedSlotConfig[h].in[2] <== seekerHRV[t][i];
			packedSlotConfig[h].in[3] <== seekerYLB[t][i];
			packedSlotConfig[h].in[4] <== seekerEND[t][i];


			// hash the prev value + this tick's values
			seekerValuesHasher[h] = Poseidon(2);
			seekerValuesHasher[h].inputs[0] <== seekerValuesHashPrev[h];
			seekerValuesHasher[h].inputs[1] <==  packedSlotConfig[h].out;
			/* seekerValuesHasher[h].inputs[1] <== seekerACT[t][i]; */
			/* seekerValuesHasher[h].inputs[2] <== seekerHRV[t][i]; */
			/* seekerValuesHasher[h].inputs[3] <== seekerYLB[t][i]; */
			/* seekerValuesHasher[h].inputs[4] <== seekerEND[t][i]; */
			/* seekerValuesHasher[h].inputs[5] <== t; */
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
			prevSeekerHRV[h] <== t == 0 ? 0 : (seekerHRV[t-1][i] * seekerValuesIsNotUpdate[h].out);
			seekerHRV[t][i] * seekerValuesIsNotUpdate[h].out === prevSeekerHRV[h];
			prevSeekerYLB[h] <== t == 0 ? 0 : (seekerYLB[t-1][i] * seekerValuesIsNotUpdate[h].out);
			seekerYLB[t][i] * seekerValuesIsNotUpdate[h].out === prevSeekerYLB[h];
			prevSeekerEND[h] <== t == 0 ? 0 : (seekerEND[t-1][i] * seekerValuesIsNotUpdate[h].out);
			seekerEND[t][i] * seekerValuesIsNotUpdate[h].out === prevSeekerEND[h];
			prevSeekerACT[h] <== t == 0 ? 0 : (seekerACT[t-1][i] * seekerValuesIsNotUpdate[h].out);
			seekerACT[t][i] * seekerValuesIsNotUpdate[h].out === prevSeekerACT[h];
			// inc
			h++;
		}
		seekerValuesHash[i] === seekerValuesHashCalc[h-1];
	}

	// for each tick, calculate the armour/health values
	component tick[numTicks];
	for(var t=0; t<numTicks; t++){
		tick[t] = Tick(numSeekers);
		for(var i=0; i<numSeekers; i++){
			tick[t].seekerHRV[i] <== seekerHRV[t][i];
			tick[t].seekerYLB[i] <== seekerYLB[t][i];
			tick[t].seekerEND[i] <== seekerEND[t][i];
			tick[t].seekerACT[i] <== seekerACT[t][i];
			tick[t].prevYield[i] <== t == 0 ? 100 : tick[t-1].nextYield[i];
		}
	}

	// pick which tick we output the values for
	component selectedSeekerYieldTick = SelectArray(numTicks, numSeekers);
	for(var i=0; i<numTicks; i++){
		for(var j=0; j<numSeekers; j++){
			selectedSeekerYieldTick.in[i][j] <== tick[i].nextYield[j];
		}
	}
	selectedSeekerYieldTick.idx <== currentTick;

	// output all seeker yields at currentTick
	for(var j=0; j<numSeekers; j++){
		yields[j] <== selectedSeekerYieldTick.out[j];
	}
}
