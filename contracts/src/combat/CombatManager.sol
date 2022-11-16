// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../types/Position.sol";
import "../Seeker.sol";
import "../Mod.sol";

import "./CombatSession.sol";

/**
 * Keeps instantiates and keeps track of sessions
 */
contract CombatManager {
    mapping(uint256 => CombatSession) public _combatSessions;

    Seeker seekerContract;
    Mod modContract;
    IPoseidonHasher hasher;

    constructor(
        Seeker _seekerContract,
        Mod _modContract,
        IPoseidonHasher _hasherContractAddr
    ) {
        seekerContract = _seekerContract;
        modContract = _modContract;
        hasher = _hasherContractAddr;
    }

    // -- ACTIONS

    function join(Position memory pos, uint256 seekerID) public {
        // TODO: assert that the player is at position
        // TODO: assert that the tile at position is an enemy tile

        uint sessionKey = getSessionKey(pos);
        CombatSession session = _combatSessions[sessionKey];

        if (address(session) == address(0)) {
            session = new CombatSession(
                seekerContract,
                modContract,
                hasher,
                getTileData(pos)
            );
            _combatSessions[sessionKey] = session;
        }

        session.join(seekerID);
    }

    function leave(Position memory pos, uint seekerID) public {
        uint sessionKey = getSessionKey(pos);
        CombatSession session = _combatSessions[sessionKey];

        require(
            address(session) != address(0),
            "CombatManager::leave: No session found with key"
        );

        session.leave(seekerID);
    }

    function equip(Position memory pos, uint seekerID, uint modID) public {
        modContract.equip(seekerID, modID);

        uint sessionKey = getSessionKey(pos);
        CombatSession session = _combatSessions[sessionKey];

        require(
            address(session) != address(0),
            "CombatManager::leave: No session found with key"
        );

        session.equip(seekerID);
    }

    // -- GETTERS

    function getSession(
        Position memory pos
    ) public view returns (CombatSession) {
        uint sessionKey = getSessionKey(pos);
        return _combatSessions[sessionKey];
    }

    function getSessionKey(Position memory pos) public pure returns (uint256) {
        return (uint256(pos.x) << 128) | pos.y;
    }

    function getTileData(
        Position memory /*pos*/
    ) public pure returns (CombatSession.CombatTileData memory) {
        return
            CombatSession.CombatTileData({
                resonance: 0,
                health: 1000,
                attack: 1,
                sessionReward: address(0),
                sessionSupply: 500,
                bonusReward: address(0),
                bonusSupply: 100,
                sessionDuration: 100, // Would this be passed in as data?
                regenDuration: 50,
                maxSpawn: 11, // zero is infinite.
                respawnSupplyDecayPerc: 10,
                minDecayedSupply: 10
            });
    }
}
