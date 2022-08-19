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
