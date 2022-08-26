// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../src/Seeker.sol";

contract SeekerTest is Test {
    Seeker public seeker;

    function setUp() public {
        seeker = new Seeker();
        seeker.setMaxSupply(1, 500);
    }

    function testMint() public {
        uint8[8] memory attrs = [
            1, // str
            2, // tough
            3, // dex
            4, // speed
            5, // vit
            6, // endur
            7, // order
            0 // corruption (ignored)
        ];
        uint id = seeker.mint(
            msg.sender,
            1,
            attrs
        );
        SeekerData memory data = seeker.getData(id);
        assertEq(data.id, 1);
        assertEq(data.generation, 1);
        assertEq(data.strength, 1+8);
        assertEq(data.toughness, 2+8);
        assertEq(data.dexterity, 3+8);
        assertEq(data.speed, 4+8);
        assertEq(data.vitality, 5+8);
        assertEq(data.endurance, 6+8);
        assertEq(data.orderId, 7);
        assertTrue(data.corruption > 0);
    }

}
