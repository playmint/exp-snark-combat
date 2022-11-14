// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../Types.sol";

import "./CombatSession.sol";

/**
 * Keeps instantiates and keeps track of sessions
 */
contract CombatManager {
    mapping(uint256 => CombatSession) public _combatSessions;

    Seeker seekerContract;
    IPoseidonHasher hasher;

    constructor(address _seekerContractAddr, address _hasherContractAddr) {
        seekerContract = Seeker(_seekerContractAddr);
        hasher = IPoseidonHasher(_hasherContractAddr);
    }

    function join(Position memory pos, uint256 seekerID) public {
        // TODO: assert that the tile at position is an enemy tile

        uint sessionKey = getSessionKey(pos);
        CombatSession session = _combatSessions[sessionKey];

        if (address(session) == address(0)) {
            session = new CombatSession(
                seekerContract,
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
        Position memory pos
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
                maxRespawn: 5,
                respawnSupplyDecayPerc: 10,
                minDecayedSupply: 10
            });
    }

    // function _joinSession(
    //     uint8 seekerID
    // ) private view returns (SlotConfig memory) {
    //     // ensure sender owns seeker
    //     require(seekerContract.ownerOf(seekerID) == tx.origin, 'not your seeker');
    //     // get the stats values
    //     uint8[8] memory attrs = seekerContract.getAttrs(seekerID);
    //     // calc affinity bonus to hrv
    //     // TODO: is corruption the right stat here?
    //     uint8 hrv = (attrs[2]+8) + uint8(9 - (
    //         max(attrs[7], session.affinity)
    //         -
    //         min(attrs[7], session.affinity)
    //     ));
    //     require(block.number - session.startTick <= NUM_TICKS, 'session ended');
    //     // build slot config
    //     return SlotConfig({
    //         action: ActionKind.JOIN,
    //         tick: uint8(block.number - session.startTick),
    //         hrv: hrv, // TODO: update seeker stats
    //         yldb: 5, // TODO: what modifies this?
    //         end: 100
    //     });
    // }
}
