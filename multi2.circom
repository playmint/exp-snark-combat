pragma circom 2.0.0;

template Multiplier2() {
    signal input seekerAttackArmour[3];
    signal input seekerAttackHealth[3];
    signal input dungeonAttackArmour[3];
    signal input dungeonAttackHealth[3];

    signal input prevTick;
    signal input prevDungeonArmour;
    signal input prevDungeonHealth;
    signal input prevSeekerArmour[3];
    signal input prevSeekerHealth[3];

    signal output nextTick;
    signal output nextDungeonArmour;
    signal output nextDungeonHealth;
    signal output nextSeekerArmour[3];
    signal output nextSeekerHealth[3];

    signal calcDungeonArmour = prevDungeonArmour;
    signal calcDungeonHealth = prevDungeonHealth;
    signal calcSeekerArmour[3];
	for(var i=0; i<3; i++){
		calcSeekerArmour[i] = prevSeekerArmour[i];
	}
    signal calcSeekerHealth[3];
	for(var i=0; i<3; i++){
		calcSeekerHealth[i] = prevSeekerHealth[i];
	}

	for(var t=0; t<100; t++){
		for(var i=0; i<3; i++){
            // dungeon attacks seeker armour
            if (calcDungeonHealth > 0) {
				// TODO: clamp min zero
                calcSeekerArmour[i] = calcSeekerArmour[i] - dungeonAttackArmour[i];
            }
            // seeker attack dungeon armour
            //if (calcSeekerHealth[i] > 0) {
                calcDungeonArmour = calcDungeonArmour - seekerAttackArmour[i];
            //}
            // dungeon attack seeker health
            if (calcDungeonHealth > 0 && calcSeekerArmour[i] == 0) {
                calcSeekerHealth[i] = calcSeekerHealth[i] - dungeonAttackHealth[i];
            }
            // seeker attack dungeon health
            if (calcSeekerHealth[i] > 0 && calcDungeonArmour == 0) {
                calcDungeonHealth = calcDungeonHealth - seekerAttackHealth[i];
            }
		}
	}

	nextTick <== prevTick + 100;

	nextDungeonArmour <== calcDungeonArmour;
 }

 component main = Multiplier2();
