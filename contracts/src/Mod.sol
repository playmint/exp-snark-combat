// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./Seeker.sol";

struct ModData {
    uint id;
    GameObjectAttr attr;
    uint8 value;
}

contract Mod is ERC721Enumerable, Ownable {
    uint256 public count;
    mapping(uint256 => ModData) public _tokenData;

    Seeker public _seekerContract;

    // modId to seekerId
    mapping(uint256 => uint256) public _modToSeeker;
    mapping(uint256 => uint256[]) public _seekerToMods;

    constructor() ERC721("Mod", "Mod") Ownable() {}

    function setSeekerContract(Seeker seekerContract) public onlyOwner {
        _seekerContract = seekerContract;
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    function equip(uint256 seekerId, uint256 modId) public {
        // Although tx.origin is frowned upon, seeing as both the Mod and the Seeker have to belong to origin and nothing
        // gets sent to sender, should be safe and not be a phishing risk.
        require(
            tx.origin == ownerOf(modId),
            "Mod::equip: sender not owner of mod token"
        );
        require(_modToSeeker[modId] == 0, "Mod::equip: Mod already equipped");
        require(
            tx.origin == _seekerContract.ownerOf(seekerId),
            "Mod::equip: sender not owner of seeker"
        );

        _modToSeeker[modId] = seekerId;
        _seekerToMods[seekerId].push(modId); // Should this be emitting an event instead of recording this on-chain?
    }

    function unequip(uint256 seekerId, uint256 modId) public {
        require(
            tx.origin == ownerOf(modId),
            "Mod::unequip: sender not owner of mod token"
        );
        require(
            _modToSeeker[modId] == seekerId,
            "Mod::unequip: Mod not equipped to seeker"
        );
        require(
            tx.origin == _seekerContract.ownerOf(seekerId), // DANGER: using origin can open up contract to phishing attack.
            "Mod::unequip: sender not owner of seeker"
        );

        _modToSeeker[modId] = 0;

        // Remove the mod from the list.
        // List is unordered so we can put the last elm into index we are deleting and pop the last elm
        uint256 len = _seekerToMods[seekerId].length;
        for (uint i = 0; i < len; i++) {
            if (_seekerToMods[seekerId][i] == modId) {
                _seekerToMods[seekerId][i] = _seekerToMods[seekerId][len - 1];
                _seekerToMods[seekerId].pop();
                break;
            }
        }
    }

    function getSeekerMods(
        uint256 seekerId
    ) public view returns (uint256[] memory) {
        return _seekerToMods[seekerId];
    }

    // mint
    function mint(
        address to,
        GameObjectAttr attr,
        uint8 value
    ) public onlyOwner returns (uint256 tokenId) {
        count++;
        tokenId = count;
        _tokenData[tokenId] = ModData(tokenId, attr, value);
        _safeMint(to, tokenId);
        return tokenId;
    }

    function getData(
        uint256 tokenId
    ) public view returns (ModData memory data) {
        return _tokenData[tokenId];
    }

    function getModdedSeekerAttrs(
        uint256 seekerId
    ) public view returns (uint8[12] memory) {
        uint8[12] memory attrs = _seekerContract.getAttrs(seekerId);
        for (uint i = 0; i < _seekerToMods[seekerId].length; i++) {
            uint256 modId = _seekerToMods[seekerId][i];
            ModData memory modData = _tokenData[modId];
            attrs[uint256(modData.attr)] += modData.value;
        }

        return attrs;
    }

    function getModdedCombatData(
        uint256 seekerId
    )
        public
        view
        returns (uint8 resonance, uint8 health, uint8 attack, uint8 criticalHit)
    {
        uint8[12] memory attrs = getModdedSeekerAttrs(seekerId);

        resonance = attrs[uint(GameObjectAttr.resonance)];
        health = attrs[uint(GameObjectAttr.health)];
        attack = attrs[uint(GameObjectAttr.attack)];
        criticalHit = attrs[uint(GameObjectAttr.criticalHit)];
    }
}
