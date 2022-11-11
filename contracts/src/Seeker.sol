// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./Types.sol";

struct SeekerData {
    uint id;
    uint generation;
    uint8 resonance; // 0
    uint8 health; // 1
    uint8 attack; // 2
    uint8 criticalHit; // 3
    uint8 agility; // 4
    uint8 scout; // 5
    uint8 capacity; // 6
    uint8 endurance; // 7
    uint8 harvest; // 8
    uint8 yieldBonus; // 9
    uint8 craftingSpeed; // 10
    uint8 modBonus; // 11
}

contract Seeker is ERC721Enumerable, Ownable {
    uint256 public _count;
    uint256[16] public _totalMinted; // by generation
    uint256[16] public _maxMintable; // by generation
    mapping(uint256 => uint256) public _attrs;
    mapping(uint256 => Position) public _position;

    constructor() ERC721("Seeker", "Seeker") Ownable() {}

    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    // mint seeker
    function mint(
        address to,
        uint8 generation,
        uint8[12] memory attrs
    ) public returns (uint256 tokenId) {
        require(
            _totalMinted[generation] < _maxMintable[generation],
            "tokenId out of range for genesis"
        );
        tokenId = _count + 1;
        _totalMinted[generation]++;
        _attrs[tokenId] = packAttrs(attrs);
        _safeMint(to, tokenId);
        _count++;
        return tokenId;
    }

    function packAttrs(
        uint8[12] memory attrs
    ) private pure returns (uint256 packed) {
        return
            0 |
            (uint256(attrs[0]) << 0) |
            (uint256(attrs[1]) << 8) |
            (uint256(attrs[2]) << 16) |
            (uint256(attrs[3]) << 24) |
            (uint256(attrs[4]) << 32) |
            (uint256(attrs[5]) << 40) |
            (uint256(attrs[6]) << 48) |
            (uint256(attrs[7]) << 56) |
            (uint256(attrs[8]) << 64) |
            (uint256(attrs[9]) << 72) |
            (uint256(attrs[10]) << 80) |
            (uint256(attrs[11]) << 88);
    }

    function unpackAttrs(
        uint256 packed
    ) private pure returns (uint8[12] memory attrs) {
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

    function getData(
        uint256 tokenId
    ) public view returns (SeekerData memory data) {
        uint8[12] memory attrs = unpackAttrs(_attrs[tokenId]);
        data.id = tokenId;
        data.generation = 1; // TODO: pull from _data
        data.resonance = attrs[0];
        data.health = attrs[1];
        data.attack = attrs[2];
        data.criticalHit = attrs[3];
        data.agility = attrs[4];
        data.scout = attrs[5];
        data.capacity = attrs[6];
        data.endurance = attrs[7];
        data.harvest = attrs[8];
        data.yieldBonus = attrs[9];
        data.craftingSpeed = attrs[10];
        data.modBonus = attrs[11];

        return data;
    }

    function getCombatData(
        uint256 tokenId
    )
        public
        view
        returns (uint8 resonance, uint8 health, uint8 attack, uint8 criticalHit)
    {
        uint8[12] memory attrs = unpackAttrs(_attrs[tokenId]);

        resonance = attrs[0];
        health = attrs[1];
        attack = attrs[2];
        criticalHit = attrs[3];
    }

    function setMaxSupply(
        uint256 generation,
        uint256 maxMintable
    ) public onlyOwner {
        require(_maxMintable[generation] == 0, "supply is immutable");
        _maxMintable[generation] = maxMintable;
    }

    // TODO: Only set by actions contract
    function setPosition(uint256 seekerId, Position memory pos) public {
        _position[seekerId] = pos;
    }

    function getPosition(
        uint256 seekerId
    ) public view returns (Position memory) {
        return _position[seekerId];
    }
}
