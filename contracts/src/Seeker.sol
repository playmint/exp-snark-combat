// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "encoding/Base64.sol";

struct SeekerData {
    uint id;
    string image;
    uint generation;
    uint8 strength;   // 0
    uint8 toughness;  // 1
    uint8 dexterity;  // 2
    uint8 speed;      // 3
    uint8 vitality;   // 4
    uint8 endurance;  // 5
    uint8 orderId;    // 6
    uint8 corruption; // 7
    string order;
    string origin;
    string element;
    string phase;
    string affinity;
    string virtue;
    string vice;
    uint16 age;
    uint16 composition;
}

contract Seeker is ERC721Enumerable, Ownable {
    string public _collectionName;
    string public _collectionDesc;
    string public _collectionImgURL;
    string public _collectionExtURL;
    uint256 public _feeBasisPoints;
    address public _feeRecipient;
    string public _imageBaseURL;

    uint256 public _count;
    uint256[16] public _totalMinted; // by generation
    uint256[16] public _maxMintable; // by generation
    mapping(uint256 => uint256) public _attrs;

    constructor() ERC721("Seeker", "Seeker") Ownable() {}

    function exists(uint256 tokenId) public view returns(bool) {
        return _exists(tokenId);
    }

    // mint seeker
    function mint(address to, uint8 generation, uint8[8] memory attrs) public returns (uint256 tokenId) {
        require(_totalMinted[generation] < _maxMintable[generation], "tokenId out of range for genesis");
        tokenId = _count + 1;
        _totalMinted[generation]++;
        _attrs[tokenId] = packAttrs(attrs);
        _safeMint(to, tokenId);
        _count++;
        return tokenId;
    }

    // newWeightedCorruption attempts to pluck a normaly distributed number
    // between 0-100 from a given uniformly distributed random seed. (ie there
    // are more 50s than there are 0s or 100s).
    function newWeightedCorruption(uint256 seed) private pure returns (uint8) {
        return uint8((0
            + (((seed >> 16) & 0xffff) % 101)
            + (((seed >> 32) & 0xffff) % 101)
            + (((seed >> 48) & 0xffff) % 101)
        ) / 3);
    }

    function packAttrs(uint8[8] memory attrs) private pure returns(uint256 packed) {
        return 0
        | (uint256(attrs[0]) << 8)
        | (uint256(attrs[1]) << 21)
        | (uint256(attrs[2]) << 34)
        | (uint256(attrs[3]) << 47)
        | (uint256(attrs[4]) << 60)
        | (uint256(attrs[5]) << 73)
        | (uint256(attrs[6]) << 86)
        | (uint256(attrs[7]) << 99);
    }

    function unpackAttrs(uint256 packed) private pure returns(uint8[8] memory attrs) {
        attrs[0] = uint8((packed >> 8) & 0x1fff);
        attrs[1] = uint8((packed >> 21) & 0x1fff);
        attrs[2] = uint8((packed >> 34) & 0x1fff);
        attrs[3] = uint8((packed >> 47) & 0x1fff);
        attrs[4] = uint8((packed >> 60) & 0x1fff);
        attrs[5] = uint8((packed >> 73) & 0x1fff);
        attrs[6] = uint8((packed >> 86) & 0x1fff);
        attrs[7] = uint8((packed >> 99) & 0x1fff);
    }

    function getAttrs(uint256 tokenId) public view returns (uint8[8] memory) {
        return unpackAttrs(_attrs[tokenId]);
    }

    function getData(uint256 tokenId) public view returns (SeekerData memory data) {
        uint8[8] memory attrs = unpackAttrs(_attrs[tokenId]);
        data.id              = tokenId;
        data.generation      = 1; // TODO: pull from _data
        data.strength        = attrs[0] + 8;
        data.toughness       = attrs[1] + 8;
        data.dexterity       = attrs[2] + 8;
        data.speed           = attrs[3] + 8;
        data.vitality        = attrs[4] + 8;
        data.endurance       = attrs[5] + 8;
        data.orderId         = attrs[6];
        data.order           = getOrders()[attrs[6]];
        data.corruption      = attrs[7];
        data.origin          = getOrigins()[getTraitIndex("ORIGIN", tokenId, 12)];
        data.element         = getElements()[getTraitIndex("ELEMENT", tokenId, 9)];
        data.phase           = getPhases()[getTraitIndex("PHASE", tokenId, 4)];
        data.affinity        = getAffinities()[getTraitIndex("AFFINITY", tokenId, 8)];
        data.virtue          = getVirtues()[getTraitIndex("VIRTUE", tokenId, 7)];
        data.vice            = getVices()[getTraitIndex("VICE", tokenId, 7)];
        data.age             = uint16(getTraitIndex("AGE", tokenId, 2000)); // TODO: this should be -1000 to 1000, is that right?
        data.composition     = uint16(getTraitIndex("COMPOSITION", tokenId, 2000)); // TODO: is this right? -1000 to 1000 again?
        data.image           = getImageURL(data);
        return data;
    }

    function getImageURL(SeekerData memory data) internal view returns (string memory) {
        return string(abi.encodePacked(
            _imageBaseURL,
            'seeker/',
            Strings.toString(data.id),
            '/',
            getImageParams(data),
            '/1080x1080.png'
        ));
    }

    function getImageParams(SeekerData memory data) internal pure returns (string memory) {
        return Base64.encode(abi.encodePacked('[',
            getAttributesJSON(data),
        ']'));
    }

    function getName(SeekerData memory data) internal pure returns (string memory) {
        return string(abi.encodePacked(
            data.corruption > 80 ? 'Corrupted ' : '',
            data.origin,
            ' of ',
            data.element
        ));
    }

    function tokenURI(uint256 tokenId) public override view returns (string memory) {
        require(_exists(tokenId), "token doesn't exist");
        SeekerData memory data = getData(tokenId);
        return string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(abi.encodePacked(
                '{"name": "', getName(data), '",',
                '"description": "Seeker",',
                '"image": "', data.image, '",',
                '"external_url": "', data.image, '",',
                '"attributes": [', getAttributesJSON(data), ']}'
            ))
        ));
    }

    function getTraitJSON(string memory key, string memory value) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '{"trait_type": "', key, '", "value": "', value, '"},'
        ));
    }

    function getTraitJSON(string memory key, uint256 value, uint256 max) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '{"trait_type": "', key, '", "value": ', Strings.toString(value), ', "max_value": ', Strings.toString(max), '},'
        ));
    }

    function getTraitJSON(string memory key, uint256 value) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '{"trait_type": "', key, '", "value": ', Strings.toString(value), '},'
        ));
    }

    function getNamedAttributesJSON(SeekerData memory data) internal pure returns (string memory) {
        return string(abi.encodePacked(
            getTraitJSON("Order", data.order),
            getTraitJSON("Origin", data.origin),
            getTraitJSON("Element", data.element),
            getTraitJSON("Phase", data.phase),
            getTraitJSON("Affinity", data.affinity),
            getTraitJSON("Virtue", data.virtue),
            getTraitJSON("Vice", data.vice),
            getTraitJSON("Age", data.age),
            getTraitJSON("Composition", data.composition)
        ));
    }

    function getStatsAttributesJSON(SeekerData memory data) internal pure returns (string memory) {
        return string(abi.encodePacked(
            getTraitJSON("Strength", data.strength, 16),
            getTraitJSON("Toughness", data.toughness, 16),
            getTraitJSON("Dexterity", data.dexterity, 16),
            getTraitJSON("Speed", data.speed, 16),
            getTraitJSON("Vitality", data.vitality, 16),
            getTraitJSON("Endurance", data.endurance, 16),
            getTraitJSON("Corruption", data.corruption, 100)
        ));
    }

    function getGenerationAttributesJSON(SeekerData memory data) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '{"trait_type": "Generation", "value": ', Strings.toString(data.generation), '}'
        ));
    }

    function getAttributesJSON(SeekerData memory data) internal pure returns (string memory) {
        return string(abi.encodePacked(
            getStatsAttributesJSON(data),
            getNamedAttributesJSON(data),
            getGenerationAttributesJSON(data) // leave this last - it's got no comma
        ));
    }

    function contractURI() public view returns(string memory) {
        return string(abi.encodePacked(
            "data:application/json;utf8,{"
            "\"name\": \"", _collectionName, "\","
            "\"description\": \"", _collectionDesc, "\","
            "\"image\": \"", _collectionImgURL, "\",",
            "\"external_link\": \"", _collectionExtURL,"\",",
            "\"seller_fee_basis_points\": \"", Strings.toString(_feeBasisPoints),"\",",
            "\"fee_recipient\": \"", Strings.toHexString(uint256(uint160(_feeRecipient)), 20),"\"",
            "}"
        ));
    }

    function random(uint256 seed) internal view returns (uint256) {
        return (uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            seed
        ))));
    }

    function getTraitIndex(string memory keyPrefix, uint256 tokenId, uint256 traitCount) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            keyPrefix,
            Strings.toString(tokenId)
        ))) % traitCount;
    }

    function getOrigins() public pure returns (string[12] memory) {
        return [
            "Wanderer",
            "Warden",
            "Keeper",
            "Highlander",
            "Shinobi",
            "Monk",
            "Mercenary",
            "Merchant",
            "Veteran",
            "Inventor",
            "Cultist",
            "Cartographer"
        ];
    }

    function getElements() public pure returns (string[9] memory) {
        return [
            "Solar",
            "Mist",
            "Flame",
            "Tides",
            "Steam",
            "Void",
            "Aether",
            "Electric",
            "Motion"
        ];
    }

    function getPhases() public pure returns (string[4] memory) {
        return [
            "Dawn",
            "Day",
            "Dusk",
            "Night"
        ];
    }

    function getAffinities() public pure returns (string[8] memory) {
        return [
            "Justice",
            "Subversion",
            "Calm",
            "Anger",
            "Greed",
            "Fame",
            "Power",
            "Unknown"
        ];
    }

    function getVirtues() public pure returns (string[7] memory) {
        return [
            "Humility",
            "Charity",
            "Chastity",
            "Gratitude",
            "Temperance",
            "Patience",
            "Diligence"
        ];
    }

    function getVices() public pure returns (string[7] memory) {
        return [
            "Lust",
            "Gluttony",
            "Greed",
            "Sloth",
            "Wrath",
            "Envy",
            "Pride"
        ];
    }

    function getOrders() public pure returns (string[16] memory) {
        return [
            "of Power",
            "of Giants",
            "of Titans",
            "of Skill",
            "of Perfection",
            "of Brilliance",
            "of Enlightenment",
            "of Protection",
            "of Anger",
            "of Rage",
            "of Fury",
            "of Vitriol",
            "of the Fox",
            "of Detection",
            "of Reflection",
            "of the Twins"
        ];
    }

    function setCollectionName(string memory collectionName) public onlyOwner {
        _collectionName = collectionName;
    }

    function setCollectionDesc(string memory collectionDesc) public onlyOwner {
        _collectionDesc = collectionDesc;
    }

    function setCollectionImgURL(string memory collectionImgURL) public onlyOwner {
        _collectionImgURL = collectionImgURL;
    }

    function setCollectionExtURL(string memory collectionExtURL) public onlyOwner {
        _collectionExtURL = collectionExtURL;
    }

    function setFeeBasisPoints(uint256 feeBasisPoints) public onlyOwner {
        _feeBasisPoints = feeBasisPoints;
    }

    function setFeeRecipient(address feeRecipient) public onlyOwner {
        _feeRecipient = feeRecipient;
    }

    function setImageBaseURL(string memory newImageBaseURL) public onlyOwner {
        _imageBaseURL = newImageBaseURL;
    }

    function setMaxSupply(uint256 generation, uint256 maxMintable) public onlyOwner {
        require(_maxMintable[generation] == 0, "supply is immutable");
        _maxMintable[generation] = maxMintable;
    }


}
