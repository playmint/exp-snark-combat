// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "encoding/Base64.sol";

import "./Seeker.sol";

struct ModData {
    uint id;
    uint8 resonance;   // 0
    uint8 health;  // 1
    uint8 attack;  // 2
    uint8 criticalHit;      // 3
    uint8 agility;   // 4
    uint8 scout;  // 5
    uint8 capacity;    // 6
    uint8 endurance; // 7
    uint8 harvest; // 8
    uint8 yieldBonus; // 9
    uint8 craftingSpeed; // 10
    uint8 modBonus; // 11
}

contract Mod is ERC721Enumerable, Ownable {
    uint256 public count;
    mapping(uint256 => uint256) public _attrs;

    Seeker public  _seekerContract;

    // modId to seekerId
    mapping(uint256 => uint256) public _modToSeeker;
    mapping(uint256 => uint256[]) public _seekerToMods;

    constructor() ERC721("Mod", "Mod") Ownable() {}

    function setSeekerContract(Seeker seekerContract) public {
        _seekerContract = seekerContract;
    }

    function exists(uint256 tokenId) public view returns(bool) {
        return _exists(tokenId);
    }

    function equip(uint256 modId, uint256 seekerId) public {
        require (_msgSender() == ownerOf(modId), "Mod::equip: sender not owner of mod token");
        require (_modToSeeker[modId] == 0, "Mod::equip: Mod already equipped");
        require (_msgSender() == _seekerContract.ownerOf(seekerId), "Mod::equip: sender not owner of seeker");

        _modToSeeker[modId] = seekerId;
        _seekerToMods[seekerId].push(modId); // Should this be emitting an event instead of recording this on-chain?
    }

    function unequip(uint256 modId, uint256 seekerId) public {
        require (_msgSender() == ownerOf(modId), "Mod::unequip: sender not owner of mod token");
        require (_modToSeeker[modId] == seekerId, "Mod::unequip: Mod not equipped to seeker");
        require (_msgSender() == _seekerContract.ownerOf(seekerId), "Mod::unequip: sender not owner of seeker");

        _modToSeeker[modId] = 0;

        // Remove the mod from the list.
        // List is unordered so we can put the last elm into index we are deleting and pop the last elm
        uint256 len = _seekerToMods[seekerId].length;
        for (uint i = 0; i < len; i++) {
            if (_seekerToMods[seekerId][i] == modId) {
                _seekerToMods[seekerId][i] = _seekerToMods[seekerId][len -1];
                _seekerToMods[seekerId].pop();
                break;
            }
        }
    }

    function getSeekerMods(uint256 seekerId) public view returns (uint256[] memory) {
        return _seekerToMods[seekerId];
    }

    // mint
    function mint(address to, uint8[12] memory attrs) public returns (uint256 tokenId) {
        count++;
        tokenId = count;
        _attrs[tokenId] = packAttrs(attrs);
        _safeMint(to, tokenId);
        return tokenId;
    }

    function packAttrs(uint8[12] memory attrs) private pure returns(uint256 packed) {
        return 0
        | (uint256(attrs[0]) << 0)
        | (uint256(attrs[1]) << 8)
        | (uint256(attrs[2]) << 16)
        | (uint256(attrs[3]) << 24)
        | (uint256(attrs[4]) << 32)
        | (uint256(attrs[5]) << 40)
        | (uint256(attrs[6]) << 48)
        | (uint256(attrs[7]) << 56)
        | (uint256(attrs[8]) << 64)
        | (uint256(attrs[9]) << 72)
        | (uint256(attrs[10]) << 80)
        | (uint256(attrs[11]) << 88);
    }

    function unpackAttrs(uint256 packed) private pure returns(uint8[12] memory attrs) {
        attrs[0] = uint8((packed >> 0) & 0xff);
        attrs[1] = uint8((packed >> 8) & 0xff);
        attrs[2] = uint8((packed >> 16) & 0xff);
        attrs[3] = uint8((packed >> 24) & 0xff);
        attrs[4] = uint8((packed >> 32) & 0xff);
        attrs[5] = uint8((packed >> 40) & 0xff);
        attrs[6] = uint8((packed >> 48) & 0xff);
        attrs[7] = uint8((packed >> 56) & 0xff);
        attrs[8] = uint8((packed >> 64) & 0xff);
        attrs[9] = uint8((packed >> 72) & 0xff);
        attrs[10] = uint8((packed >> 80) & 0xff);
        attrs[11] = uint8((packed >> 88) & 0xff);
    }

    function getAttrs(uint256 tokenId) public view returns (uint8[12] memory) {
        return unpackAttrs(_attrs[tokenId]);
    }

    function getData(uint256 tokenId) public view returns (ModData memory data) {
        uint8[12] memory attrs = unpackAttrs(_attrs[tokenId]);
        data.id              = tokenId;
        data.resonance       = attrs[0];
        data.health          = attrs[1];
        data.attack          = attrs[2];
        data.criticalHit     = attrs[3];
        data.agility         = attrs[4];
        data.scout           = attrs[5];
        data.capacity        = attrs[6];
        data.endurance       = attrs[7];
        data.harvest         = attrs[8];
        data.yieldBonus      = attrs[9];
        data.craftingSpeed   = attrs[10];
        data.modBonus        = attrs[11];

        return data;
    }

    function getModdedSeekerAttrs(uint256 seekerId) public view returns (uint8[12] memory) {
        uint8[12] memory attrs = _seekerContract.getAttrs(seekerId);
        for (uint i = 0; i < _seekerToMods[seekerId].length; i++) {
            uint8[12] memory modAttrs = getAttrs(_seekerToMods[seekerId][i]);
            for (uint j = 0; j < 12; j++) {
                attrs[j] += modAttrs[j]; // Any gas savings if I check if modAttrs[j] > 0?
            }
        }

        return attrs;
    }

}
