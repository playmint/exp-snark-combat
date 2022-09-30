pragma circom 2.0.0;

include "templates.circom";

component main {
	public [
		seekerHRV,
		seekerYLB,
		seekerEND,
		seekerACT,
		currentTick
	]
} = CombatNoHash(3, 100);
