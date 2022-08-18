pragma circom 2.0.0;

template Tick() {
    signal input seekerAttackArmour[3];
    signal input seekerAttackHealth[3];
    signal input dungeonAttackArmour[3];
    signal input dungeonAttackHealth[3];

    signal input prevDungeonArmour;
    signal input prevDungeonHealth;
    signal input prevSeekerArmour[3];
    signal input prevSeekerHealth[3];

    signal input nextDungeonArmour;
    signal input nextDungeonHealth;
    signal input nextSeekerArmour[3];
    signal input nextSeekerHealth[3];

	signal seekerAlive[3];

	for(var i=0; i<3; i++){
		nextSeekerArmour[i] === prevSeekerArmour[i] - dungeonAttackArmour[i];
		nextDungeonArmour === prevDungeonArmour - seekerAttackArmour[i];
		nextSeekerHealth[i] === prevSeekerHealth[i] - dungeonAttackHealth[i];
		nextDungeonHealth === prevDungeonHealth - seekerAttackHealth[i];
	}

}

template Combat() {
    signal input seekerAttackArmour[3];
    signal input seekerAttackHealth[3];
    signal input dungeonAttackArmour[3];
    signal input dungeonAttackHealth[3];

    signal input dungeonArmour[100];
    signal input dungeonHealth[100];
    signal input seekerArmour[100][3];
    signal input seekerHealth[100][3];

    signal output out;

	component tick[100];

	// wireup t=0
	tick[0] = Tick();
	dungeonArmour[0] ==> tick[0].prevDungeonArmour;
	dungeonHealth[0] ==> tick[0].prevDungeonHealth;
	for(var i=0; i<3; i++){
		seekerAttackArmour[i] ==> tick[0].seekerAttackArmour[i];
		seekerAttackHealth[i] ==> tick[0].seekerAttackHealth[i];
		dungeonAttackArmour[i] ==> tick[0].dungeonAttackArmour[i];
		dungeonAttackHealth[i] ==> tick[0].dungeonAttackHealth[i];
		seekerArmour[0][i] ==> tick[0].prevSeekerArmour[i];
		seekerHealth[0][i] ==> tick[0].prevSeekerHealth[i];
	}

	// wireup t=1+
	for(var t=1; t<100; t++){
		tick[t] = Tick();
		dungeonArmour[t-1] ==> tick[t].prevDungeonArmour;
		dungeonArmour[t] ==> tick[t].nextDungeonArmour;
		dungeonHealth[t-1] ==> tick[t].prevDungeonHealth;
		dungeonHealth[t] ==> tick[t].nextDungeonHealth;
		for(var i=0; i<3; i++){
			seekerAttackArmour[i] ==> tick[t].seekerAttackArmour[i];
			seekerAttackHealth[i] ==> tick[t].seekerAttackHealth[i];
			dungeonAttackArmour[i] ==> tick[t].dungeonAttackArmour[i];
			dungeonAttackHealth[i] ==> tick[t].dungeonAttackHealth[i];
		}
	}

	out <== tick[99].nextDungeonHealth;


 }

 component main = Combat();
