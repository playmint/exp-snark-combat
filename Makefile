NUM_SEEKERS=3

.PHONY: verify
verify: proof.json verification_key.json
	snarkjs groth16 verify verification_key.json input.json proof.json

verifier.sol: combat_0001.zkey
	snarkjs zkey export solidityverifier combat_0001.zkey verifier.sol

multi.wasm: multi.circom
	circom multi.circom --wasm

multi.r1cs: multi.circom
	circom multi.circom --r1cs

public.json: generate_inputs.js
	node generate_inputs.js 5 > public.json

multi_js/witness.wtns: public.json multi.wasm
	(cd multi_js && node generate_witness.js multi.wasm ../public.json witness.wtns)

proof.json: multi_js/witness.wtns combat_0001.zkey public.json
	cp public.json input.json
	snarkjs groth16 prove combat_0001.zkey multi_js/witness.wtns ./proof.json ./input.json

verification_key.json: combat_0001.zkey
	snarkjs zkey export verificationkey combat_0001.zkey verification_key.json

combat_0001.zkey: combat_0000.zkey
	echo 'yyy' | snarkjs zkey contribute combat_0000.zkey combat_0001.zkey --name="1st Contributor Name" -v

combat_0000.zkey: pot_final.ptau multi.r1cs
	snarkjs groth16 setup multi.r1cs pot_final.ptau combat_0000.zkey

pot_final.ptau:
	snarkjs powersoftau new bn128 24 pot_0000.ptau -v
	echo 'xxx' | snarkjs powersoftau contribute pot_0000.ptau pot_0001.ptau --name="First contribution" -v
	snarkjs powersoftau prepare phase2 pot_0001.ptau pot_final.ptau -v

.PHONY: clean
clean:
	rm -f public.json
	rm -f input.json
	rm -rf multi_js
	rm -f multi.r1cs multi.wasm
	rm -f pot_0000.ptau pot_0001.ptau
	rm -f combat_0000.zkey combat_0001.zkey
	rm -f verification_key.json
	rm -f proof.json
	rm -f verifier.sol

