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

enum GameObjectAttr {
    resonance, // 0
    health, // 1
    attack, // 2
    criticalHit, // 3
    agility, // 4
    scout, // 5
    capacity, // 6
    endurance, // 7
    harvest, // 8
    yieldBonus, // 9
    assemblySpeed, // 10
    modBonus // 11
}

contract Mod is ERC721Enumerable, Ownable {
    uint256 public count;
    mapping(uint256 => ModData) public _tokenData;

    Seeker public _seekerContract;

    // modId to seekerId
    mapping(uint256 => uint256) public _modToSeeker;
    mapping(uint256 => uint256[]) public _seekerToMods;

    constructor() ERC721("Mod", "Mod") Ownable() {}

    function setSeekerContract(Seeker seekerContract) public {
        _seekerContract = seekerContract;
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    function equip(uint256 modId, uint256 seekerId) public {
        require(
            _msgSender() == ownerOf(modId),
            "Mod::equip: sender not owner of mod token"
        );
        require(_modToSeeker[modId] == 0, "Mod::equip: Mod already equipped");
        require(
            _msgSender() == _seekerContract.ownerOf(seekerId),
            "Mod::equip: sender not owner of seeker"
        );

        _modToSeeker[modId] = seekerId;
        _seekerToMods[seekerId].push(modId); // Should this be emitting an event instead of recording this on-chain?
    }

    function unequip(uint256 modId, uint256 seekerId) public {
        require(
            _msgSender() == ownerOf(modId),
            "Mod::unequip: sender not owner of mod token"
        );
        require(
            _modToSeeker[modId] == seekerId,
            "Mod::unequip: Mod not equipped to seeker"
        );
        require(
            _msgSender() == _seekerContract.ownerOf(seekerId),
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
    ) public returns (uint256 tokenId) {
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
}
