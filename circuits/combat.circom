pragma circom 2.0.0;

include "templates.circom";

component main {
	public [
		seekerValuesHash,
		currentTick
	]
} = Combat(3, 100);
