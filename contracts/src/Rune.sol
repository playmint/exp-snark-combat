// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./Alignment.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "encoding/Base64.sol";

contract Rune is ERC721Enumerable, Ownable {
    uint256 public count;
    mapping(uint256 => Alignment) public alignments;

    constructor() ERC721("Rune", "Rune") Ownable() {}

    function exists(uint256 tokenId) public view returns(bool) {
        return _exists(tokenId);
    }

    // mint
    function mint(address to, Alignment alignment) public returns (uint256 tokenId) {
        count++;
        tokenId = count;
        alignments[tokenId] = alignment;
        _safeMint(to, tokenId);
        return tokenId;
    }

    function getAlignment(uint tokenId) public view returns (Alignment) {
        return alignments[tokenId];
    }

    function tokenURI(uint256 tokenId) public override view returns (string memory) {
        require(_exists(tokenId), "token doesn't exist");
        Alignment alignment = alignments[tokenId];
        return string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(abi.encodePacked(
                '{"name": "Rune #', Strings.toString(tokenId), '",',
                '"description": "Rune",',
                '"image": "https://example.com/not-set",',
                '"external_url": "https://example.com/not-set",',
                '"attributes": [', getAttributesJSON(alignment), ']}'
            ))
        ));
    }

    function getAttributesJSON(Alignment alignment) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '{"trait_type": "Alignment", "value": ', Strings.toString(uint256(alignment)), '}'
        ));
    }

    function contractURI() public pure returns(string memory) {
        return string(abi.encodePacked(
            "data:application/json;utf8,{"
            "\"name\": \"Rune\","
            "\"description\": \"Runes\","
            "\"image\": \"https://example.com/not-set\",",
            "\"external_link\": \"https://example.com/not-set\",",
            "\"seller_fee_basis_points\": \"0\",",
            "\"fee_recipient\": \"0x0\"",
            "}"
        ));
    }

}
