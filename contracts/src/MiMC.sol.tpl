
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

contract MiMCHasher {
    function MiMCSponge(uint256 in_xL, uint256 in_xR) public pure returns (uint256 xL, uint256 xR);
}

contract MiMC {

    MiMCHasher hasher;

    constructor() {
        bytes memory args = abi.encode(/*arg1, arg2*/);
        bytes memory contractBytes = CONTRACT_BYTES;
        bytes memory bytecode = abi.encodePacked(contractBytes, args);
        address addr;
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        hasher = MiMCHasher(addr);
    }

    function MiMCSponge(uint256 in_xL, uint256 in_xR) public pure returns (uint256 xL, uint256 xR) {
        return hasher.MiMCSponge(in_xL, in_xR);
    }
}
