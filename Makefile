
.PHONY: verify
verify: proof.json verification_key.json
	snarkjs groth16 verify verification_key.json input.json proof.json

verifier.sol: combat_0001.zkey
	snarkjs zkey export solidityverifier combat_0001.zkey verifier.sol

combat.wasm: combat.circom
	circom combat.circom --wasm

combat.r1cs: combat.circom
	circom combat.circom --r1cs

public.json: generate_inputs.js
	node generate_inputs.js 5 > public.json

combat_js/witness.wtns: public.json combat.wasm
	(cd combat_js && node generate_witness.js combat.wasm ../public.json witness.wtns)

proof.json: combat_js/witness.wtns combat_0001.zkey public.json
	cp public.json input.json
	snarkjs groth16 prove combat_0001.zkey combat_js/witness.wtns ./proof.json ./input.json

verification_key.json: combat_0001.zkey
	snarkjs zkey export verificationkey combat_0001.zkey verification_key.json

combat_0001.zkey: combat_0000.zkey
	echo 'yyy' | snarkjs zkey contribute combat_0000.zkey combat_0001.zkey --name="1st Contributor Name" -v

combat_0000.zkey: pot_final.ptau combat.r1cs
	snarkjs groth16 setup combat.r1cs pot_final.ptau combat_0000.zkey

pot_final.ptau:
	snarkjs powersoftau new bn128 24 pot_0000.ptau -v
	echo 'xxx' | snarkjs powersoftau contribute pot_0000.ptau pot_0001.ptau --name="First contribution" -v
	snarkjs powersoftau prepare phase2 pot_0001.ptau pot_final.ptau -v

.PHONY: clean
clean:
	rm -f public.json
	rm -f input.json
	rm -rf combat_js
	rm -f combat.r1cs combat.wasm
	rm -f pot_0000.ptau pot_0001.ptau
	rm -f combat_0000.zkey combat_0001.zkey
	rm -f verification_key.json
	rm -f proof.json
	rm -f verifier.sol

