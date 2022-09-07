// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../src/Rune.sol";

contract RuneTest is Test {
    Rune public rune;

    function setUp() public {
        rune = new Rune();
    }

    function testMintCorrectAlignment() public {
        uint id = rune.mint(msg.sender, Alignment.DARK);
        Alignment alignment = rune.alignments(id);
        assertEq(id, 1);
        assertEq(uint(alignment), uint(Alignment.DARK));
    }

}
