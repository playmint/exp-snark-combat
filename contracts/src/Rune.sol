// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./Alignment.sol";

contract Rune {

    constructor() {}

    function getAlignment(uint /* runeTypeID */) public pure returns (Alignment) {
        return Alignment.NONE;
    }

    function ownerOf(uint) public pure returns (address) {
        return address(0);
    }
}
