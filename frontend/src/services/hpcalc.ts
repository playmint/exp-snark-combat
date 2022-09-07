/** @format */

import { BigNumber } from '@ethersproject/bignumber';
import { utils } from 'ethers';



// port of funcs from contracts below

const WEAPON_COUNT = 18;
const CHEST_COUNT = 15;
const HEAD_COUNT = 15;
const WAIST_COUNT = 15;
const FOOT_COUNT = 15;
const HAND_COUNT = 15;
const NECK_COUNT = 3;
const RING_COUNT = 5;
const SUFFIX_COUNT = 16;
const NAME_PREFIX_COUNT = 69;
const NAME_SUFFIX_COUNT = 18;

const SOULLESS_COUNT = 3;
const DEMIGOD_COUNT = 5;
const ROOM_COUNT = 15;
const PASSAGEWAYS_COUNT = 15;
const ARTEFACT_COUNT = 15;
const MONSTER_COUNT = 15;
const TRAP_COUNT = 15;
const ENEMY_COUNT = 18;

const CLASSIFICATION_TYPE = {
    Weapon: 0,
    Chest: 1,
    Head: 2,
    Waist: 3,
    Foot: 4,
    Hand: 5,
    Neck: 6,
    Ring: 7
};

const CLASSIFICATION_MATERIAL = {
    Heavy: 0,
    Medium: 1,
    Dark: 2,
    Light: 3,
    Cloth: 4,
    Hide: 5,
    Metal: 6,
    Jewellery: 7
};

const CLASSIFICATION_CLASS = {
    Warrior: 0,
    Hunter: 1,
    Mage: 2,
    Any: 3
};

const ChestLastClothIndex = 4;
const ChestLastLeatherIndex = 9;
const ArmourLastMetalIndex = 4;
const ArmourLasLeatherIndex = 9;
const WeaponLastHeavyIndex = 4;
const WeaponLastMediumIndex = 9;
const WeaponLastDarkIndex = 13;

function tokenComponents(tokenId: number, keyPrefix: string, itemCount: number) {
    const rand = random(keyPrefix, tokenId);
    const components = [rand.mod(itemCount).toNumber(), 0, 0, 0, 0];
    const greatness = rand.mod(21).toNumber();
    if (greatness > 14) {
        components[1] = rand.mod(SUFFIX_COUNT).toNumber() + 1;
    }
    if (greatness >= 19) {
        components[2] = rand.mod(NAME_PREFIX_COUNT).toNumber() + 1;
        components[3] = rand.mod(NAME_SUFFIX_COUNT).toNumber() + 1;
        if (greatness == 19) {
            // ...
        } else {
            components[4] = 1;
        }
    }
    return components;
}

function random(...args: any[]) {
    return BigNumber.from(utils.keccak256(utils.toUtf8Bytes(args.join(''))));
}

export function getRaidHitPoints(dungeonId: number, currentHitPoints: number[], lootToken: number) {
    const itemScores = [0, 0, 0, 0, 0, 0, 0, 0];
    const results = [0, 0, 0, 0, 0, 0, 0, 0, 0];

    if (currentHitPoints[0] > 0) {
        const weapon = tokenComponents(lootToken, 'WEAPON', WEAPON_COUNT);
        itemScores[0] = getItemHitPoints(dungeonId, weapon, 'ENEMIES', ENEMY_COUNT, CLASSIFICATION_TYPE.Weapon);
    }

    if (currentHitPoints[1] > 0) {
        const chest = tokenComponents(lootToken, 'CHEST', CHEST_COUNT);
        itemScores[1] = getItemHitPoints(dungeonId, chest, 'TRAPS', TRAP_COUNT, CLASSIFICATION_TYPE.Chest);
    }

    if (currentHitPoints[2] > 0) {
        const head = tokenComponents(lootToken, 'HEAD', HEAD_COUNT);
        itemScores[2] = getItemHitPoints(dungeonId, head, 'MONSTERS', MONSTER_COUNT, CLASSIFICATION_TYPE.Head);
    }

    if (currentHitPoints[3] > 0) {
        const waist = tokenComponents(lootToken, 'WAIST', WAIST_COUNT);
        itemScores[3] = getItemHitPoints(dungeonId, waist, 'ARTEFACTS', ARTEFACT_COUNT, CLASSIFICATION_TYPE.Waist);
    }

    if (currentHitPoints[4] > 0) {
        const foot = tokenComponents(lootToken, 'FOOT', FOOT_COUNT);
        itemScores[4] = getItemHitPoints(dungeonId, foot, 'PASSAGEWAYS', PASSAGEWAYS_COUNT, CLASSIFICATION_TYPE.Foot);
    }

    if (currentHitPoints[5] > 0) {
        const hand = tokenComponents(lootToken, 'HAND', HAND_COUNT);
        itemScores[5] = getItemHitPoints(dungeonId, hand, 'ROOMS', ROOM_COUNT, CLASSIFICATION_TYPE.Hand);
    }

    if (currentHitPoints[6] > 0) {
        const neck = tokenComponents(lootToken, 'NECK', NECK_COUNT);
        itemScores[6] = getItemHitPoints(dungeonId, neck, 'SOULLESS', SOULLESS_COUNT, CLASSIFICATION_TYPE.Neck);
    }

    if (currentHitPoints[7] > 0) {
        const ring = tokenComponents(lootToken, 'RING', RING_COUNT);
        itemScores[7] = getItemHitPoints(dungeonId, ring, 'ELEMENTS', DEMIGOD_COUNT, CLASSIFICATION_TYPE.Ring);
    }

    for (let i = 0; i < 8; i++) {
        applyRaidItem(i, itemScores[i], currentHitPoints[i], results);
    }

    return results;
}

function applyRaidItem(raidIndex: number, raidScore: number, maxScore: number, results: number[]) {
    const score = raidScore > maxScore ? maxScore : raidScore;
    results[raidIndex] = score;
    results[8] += score;
}

function getItemHitPoints(
    dungeonId: number,
    lootComponents: any[],
    traitName: string,
    traitCount: number,
    lootType: number
) {
    const dungeonTraitIndex = pluckDungeonTrait(dungeonId, traitName, traitCount);
    const lootTypeIndex = lootComponents[0];

    const orderMatch = lootComponents[1] == getDungeonOrderIndex(dungeonId) + 1;
    let orderScore = 0;

    if (orderMatch) {
        orderScore = 2;
        if (lootComponents[4] > 0) {
            orderScore += 1;
        }
    }

    if (dungeonTraitIndex == lootTypeIndex) {
        // perfect match (and presumed class match)
        return orderScore + 2;
    }

    // there is an order match but not direct hit
    // if the item is of the correct class and more powerful than exact macth get the order orderScore
    const dungeonClass = getClass(lootType, dungeonTraitIndex);
    const lootClass = getClass(lootType, lootTypeIndex);
    if (dungeonClass == lootClass && dungeonClass != CLASSIFICATION_CLASS.Any) {
        const dungeonRank = getRank(lootType, dungeonTraitIndex);
        const lootRank = getRank(lootType, lootTypeIndex);

        if (lootRank <= dungeonRank) {
            // class hit of high enough rank
            return orderScore + 1;
        }
    }

    return orderScore;
}

function pluckDungeonTrait(dungeonId: number, keyPrefix: string, traitCount: number) {
    const rand = random(keyPrefix, (dungeonId + 16).toString());
    return rand.mod(traitCount).toNumber();
}

function getDungeonOrderIndex(dungeonId: number) {
    return dungeonId % 16;
}

function getMaterial(lootType: number, index: number) {
    if (lootType == CLASSIFICATION_TYPE.Weapon) {
        return getWeaponMaterial(index);
    }

    if (lootType == CLASSIFICATION_TYPE.Chest) {
        return getChestMaterial(index);
    }

    if (
        lootType == CLASSIFICATION_TYPE.Head ||
        lootType == CLASSIFICATION_TYPE.Waist ||
        lootType == CLASSIFICATION_TYPE.Foot ||
        lootType == CLASSIFICATION_TYPE.Hand
    ) {
        return getArmourMaterial(index);
    }

    return CLASSIFICATION_MATERIAL.Jewellery;
}

function getWeaponMaterial(index: number) {
    if (index <= WeaponLastHeavyIndex) {
        return CLASSIFICATION_MATERIAL.Heavy;
    }

    if (index <= WeaponLastMediumIndex) {
        return CLASSIFICATION_MATERIAL.Medium;
    }

    if (index <= WeaponLastDarkIndex) {
        return CLASSIFICATION_MATERIAL.Dark;
    }

    return CLASSIFICATION_MATERIAL.Light;
}

function getChestMaterial(index: number) {
    if (index <= ChestLastClothIndex) {
        return CLASSIFICATION_MATERIAL.Cloth;
    }

    if (index <= ChestLastLeatherIndex) {
        return CLASSIFICATION_MATERIAL.Hide;
    }

    return CLASSIFICATION_MATERIAL.Metal;
}

function getClass(lootType: number, index: number) {
    const material = getMaterial(lootType, index);
    return getClassFromMaterial(material);
}

function getClassFromMaterial(material: number) {
    if (material == CLASSIFICATION_MATERIAL.Heavy || material == CLASSIFICATION_MATERIAL.Metal) {
        return CLASSIFICATION_CLASS.Warrior;
    }

    if (material == CLASSIFICATION_MATERIAL.Medium || material == CLASSIFICATION_MATERIAL.Hide) {
        return CLASSIFICATION_CLASS.Hunter;
    }

    if (
        material == CLASSIFICATION_MATERIAL.Dark ||
        material == CLASSIFICATION_MATERIAL.Light ||
        material == CLASSIFICATION_MATERIAL.Cloth
    ) {
        return CLASSIFICATION_CLASS.Mage;
    }

    return CLASSIFICATION_CLASS.Any;
}

function getRank(lootType: number, index: number) {
    if (lootType == CLASSIFICATION_TYPE.Weapon) {
        return getWeaponRank(index);
    }

    if (lootType == CLASSIFICATION_TYPE.Chest) {
        return getChestRank(index);
    }

    if (
        lootType == CLASSIFICATION_TYPE.Head ||
        lootType == CLASSIFICATION_TYPE.Waist ||
        lootType == CLASSIFICATION_TYPE.Foot ||
        lootType == CLASSIFICATION_TYPE.Hand
    ) {
        return getArmourRank(index);
    }

    if (lootType == CLASSIFICATION_TYPE.Ring) {
        return getRingRank(index);
    }

    return getNeckRank(index);
}

function getWeaponRank(index: number) {
    if (index <= WeaponLastHeavyIndex) {
        return index + 1;
    }

    if (index <= WeaponLastMediumIndex) {
        return index - 4;
    }

    if (index <= WeaponLastDarkIndex) {
        return index - 9;
    }

    return index - 13;
}

function getChestRank(index: number) {
    if (index <= ChestLastClothIndex) {
        return index + 1;
    }

    if (index <= ChestLastLeatherIndex) {
        return index - 4;
    }

    return index - 9;
}

function getArmourRank(index: number) {
    if (index <= ArmourLastMetalIndex) {
        return index + 1;
    }

    if (index <= ArmourLasLeatherIndex) {
        return index - 4;
    }

    return index - 9;
}

function getRingRank(index: number) {
    return index + 1;
}

function getNeckRank(index: number) {
    return 3 - index;
}

function getArmourMaterial(index: number) {
    if (index <= ArmourLastMetalIndex) {
        return CLASSIFICATION_MATERIAL.Metal;
    }

    if (index <= ArmourLasLeatherIndex) {
        return CLASSIFICATION_MATERIAL.Hide;
    }

    return CLASSIFICATION_MATERIAL.Cloth;
}
