# Combat SNARK

## Overview

Experiment to implement DS/Crypt combat logic as a SNARK so that processing of
the current state can be performed off-chain and verification of the current
health of dungeons and seekers can be performed on-chain.

## Usage

The bulk of the combat loop is in `combat.circom`

To build the circuit, generate some test inputs, build a witness/proof and then verify it as a quick smoke test:

```
make verify
```

## TODO

* [ ] pass in block number, seekerVitality, and seekerDexterity as inputs
* [ ] regen health every block % vitality
* [ ] seeker only attack every block % dexterity

* [x] 721 seeker contract with attrs + test mint
* [ ] 1155 rune contract + test mint
* [ ] dungeon contract
	* [x] init with 3x run types, hitpoints, 5x empty seeker slots
	* [x] enterDungeon(runeIDs) - append seeker info + hash
	* [ ] claimRune(level, proof) - proof that level reached
	* [ ] useHealth() - buy a potion to restore health
	* [ ] leaveDungeon()
	* [ ] claimReward(proof) - proof that dungeon health==0


* [ ] emit event on appendAction
* [ ]
