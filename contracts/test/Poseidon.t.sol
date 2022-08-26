// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
// import "../src/Poseidon.sol";

interface ITestPoseidonHasher {
    function poseidon(uint256[5] memory inp) external pure returns (uint256 out);
}

contract PoseidonTest is Test {
    ITestPoseidonHasher public hasher;

    function setUp() public {
        bytes memory args = abi.encode(/*arg1, arg2*/);
        bytes memory contractBytes = vm.envBytes("POSEIDON_CONTRACT_BYTES");
        bytes memory bytecode = abi.encodePacked(contractBytes, args);
        address addr;
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        hasher = ITestPoseidonHasher(addr);
    }

    function testPoseidonHash() public {
        uint256[5] memory args;
        args[0] = 101;
        args[1] = 202;
        args[2] = 303;
        args[3] = 404;
        args[4] = 505;
        uint256 hash = hasher.poseidon(args);
        assertEq(
            hash,
            // magic expected value generated by the circomlibjs poseidon() func
            3888383430554338762821833378511423896625125547251316892259385396634682948908
        );
    }


}
