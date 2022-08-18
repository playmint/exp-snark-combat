
const commands = {
    UPDATE_FIGHT: 0,
    JOIN_FIGHT: 10,
    LEAVE_FIGHT: 20,
    SET_RUNE: 30,
};

const state = {
    tick: 0,
    dungeon: {
        health: 100,
        armour: 100,
        attackArmour: [ // each index in this list corrosponds to a seeker index in the seekers list in the state
            2,
            2,
        ],
        attackHealth: [ // each index in this list corrosponds to a seeker index in the seekers list in the state
            4,
            4,
        ],
    },
    seekers: [],
};

// computed seeker stats (after rune config)
// ie attack is a "rate" computed as STRENGTH+ALIGHMENT_BONUS hp every DEXTERITY ticks
const seekers = [
    {
        id: 1,
        health: 100,
        armour: 50,
        attackArmour: 4,
        attackHealth: 4,
        strength1: 4,
        dexterity: 3,
        speed: 2,
        endurance: 3,
    },
];

// str=100, dex=20 .... rate=0.5 per tick
// str=100, dex=10 .... rate=1 per tick

const applyUpdate = (state, currentTick) => {
    const d = state.dungeon;
    for (let t=state.tick; t<=currentTick; t++) {
        for (let i=0; i<state.seekers.length; i++) {
            const s = state.seekers[i];
            // dungeon attacks seeker armour
            if (d.health > 0) {
                s.armour = Math.max(0, s.armour - d.attackArmour[i]);
            }
            // seeker attack dungeon armour
            if (s.health > 0) {
                d.armour = Math.max(0, d.armour - s.attackArmour);
            }
            // dungeon attack seeker health
            if (d.health > 0 && s.armour === 0) {
                s.health = Math.max(0, s.health - d.attackHealth[i]);
            }
            // seeker attack dungeon health
            if (s.health > 0 && d.armour === 0) {
                d.health = Math.max(0, d.health - s.attackHealth);
            }
        }
    }
    return state;
}

// applyUpdateRate attempts to avoid the per-tick loop by calculating "rates" of attack
const applyUpdateRate = (state, tick) => {

    // calc the point at which each seeker will die (assuming dungeon is invunerable)
    const seekersDefence = state.seekers.map((s, idx) => {
        const attackSeekerArmourRate = dungeon.attackArmour[idx];
        const seekerArmourDefeatedAt = state.tick + Math.round(s.armour / attackSeekerArmourRate);
        const attackSeekerHealthRate = dungeon.attackHealth[idx];
        const seekerHealthDefeatedAt = seekerArmourDefeatedAt + Math.round(s.health / attackSeekerHealthRate);

        const maxTicksAttackingDungeonArmour = Math.min(currentTick, seekerArmourDefeatedAt) - state.tick;
        const maxTicksAttackingDungeonHealth = Math.min(currentTick, seekerHealthDefeatedAt) - state.tick;

        const maxHitpointsAttackingDungeonArmour = Math.floor(s.attackArmour * maxTicksAttackingDungeonArmour);
        const maxHitpointsAttackingDungeonHealth = Math.floor(s.attackHealth * maxTicksAttackingDungeonHealth);
        return {
            attackSeekerArmourRate,
            attackSeekerHealthRate,
            seekerArmourDefeatedAt,
            seekerHealthDefeatedAt,
            maxTicksAttackingDungeonArmour,
            maxTicksAttackingDungeonHealth,
        };
    });


    // calc hp from seekers -> dungeon
    const totalHitpointsAttackingDungeonArmour = seekers.reduce((hp, s) => return hp += seekersDefence[idx].maxHitpointsAttackingDungeonArmour, 0);
    const totalHitpointsAttackingDungeonHealth = seekers.reduce((hp, s) => return hp += seekersDefence[idx].maxHitpointsAttackingDungeonHealth, 0);

    // calc average combined seeker -> dungeon attack rate spread over the period
    const averageRateAttackingDungeonArmour = totalHitpointsAttackingDungeonArmour / (currentTick - state.tick);
    const averageRateAttackingDungeonHealth = totalHitpointsAttackingDungeonHealth / (currentTick - state.tick);

    // calc point at which dungeon dies
    // [!]: think! using the average rate like this is obviously wrong but I can't think of a better way
    const dungeonArmourDefeatedAt = state.tick + Math.round(dungeon.armour / averageRateAttackingDungeonArmour);

    const attackDungeonHealthRate = seekers.reduce((rate, s) => rate += s.attackHealth, 0); // attack is STRENGTH+ALIGNMENT_BONUS hp every DEXTERITY ticks...
    const dungeonHealthDefatedAt = dungeonArmourDefeatedAt + Math.round(dungeon.health / attackDungeonHealthRate);


    // ticks | 1 2 3 4 5 6 7 8 9
    // d1    | -----------------
    // s1    | --------x
    // s2    | --------------x

    state.seekers = state.seekers.map((s, idx) => {
        const ticksAttackingSeekerArmour = Math.min(currentTick, seekersDefence[idx].seekerArmourDefeatedAt) - state.tick;
        const armour = s.armour - Math.round(seekersDefence[idx].attackSeekerArmourRate * ticksAttackingSeekerArmour); // [!] THINK: round vs floor?

        const ticksAttackingSeekerHealth = Math.min(seekersDefence[idx].seekerHealthDefatedAt, seekersDefence[idx].seekerHealthDefeatedAt) - state.tick;
        const health = s.health - Math.round(seekersDefence[idx].attackSeekerArmourRate * ticksAttackingSeekerArmour); // [!] THINK: round vs floor?
        return {
            ...s,
            health,
            armour,
        };
    });

    const ticksAttackingDungeonHealth = Math.min(dungeonHealthDefatedAt, dungeonHealthDefatedAt) - state.tick;
    state.dungeon.health = dungeon.health - Math.round(attackDungeonHealthRate * ticksAttackingDungeonHealth);

    const ticksAttackingDungeonArmour = Math.min(currentTick, dungeonArmourDefeatedAt) - state.tick;
    state.dungeon.armour = dungeon.armour - Math.round(attackDungeonArmourRate * ticksAttackingDungeonArmour); // [!] THINK: round vs floor?

    return state;
}

const applyJoin = (state, currentTick, seekerID) => {
    state = applyUpdate(state, currentTick);
    state.seekers.push( seekers[seekerID] ); // TODO: check if already in state
    return state;
}

const applyLeave = (state, currentTick, seekerID) => {
    state = applyUpdate(state, currentTick);
    state.seekers = state.seekers.reduce((seekers, seeker) => {
        if (seeker.id != seekerID) {
            seekers.push(seeker);
        }
        return seekers;
    },[]);
    return state;
}

const apply = (state, currentTick, command, ...args) => {
    switch (command) {
        case commands.UPDATE_FIGHT:
            return applyUpdate(state, currentTick, ...args);
        case commands.JOIN_FIGHT:
            return applyJoin(state, currentTick, ...args);
        case commands.LEAVE_FIGHT:
            return applyLeave(state, currentTick, ...args);
        case commands.SET_RUNE:
            return applyRune(state, currentTick, ...args);
        default:
            throw new Error('invalid command');
}

////////////////////////////


