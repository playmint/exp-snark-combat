NUM_SEEKERS=3

.PHONY: verify
verify: proof.json verification_key.json
	snarkjs groth16 verify verification_key.json input.json proof.json

verifier.sol: multiplier2_0001.zkey
	snarkjs zkey export solidityverifier multiplier2_0001.zkey verifier.sol

multi.wasm: multi.circom
	circom multi.circom --wasm

multi.r1cs: multi.circom
	circom multi.circom --r1cs

public.json:
	node generate_inputs.js 5 > public.json

multi_js/witness.wtns: public.json multi.wasm
	(cd multi_js && node generate_witness.js multi.wasm ../public.json witness.wtns)

proof.json: multi_js/witness.wtns multiplier2_0001.zkey public.json
	cp public.json input.json
	snarkjs groth16 prove multiplier2_0001.zkey multi_js/witness.wtns ./proof.json ./input.json

verification_key.json: multiplier2_0001.zkey
	snarkjs zkey export verificationkey multiplier2_0001.zkey verification_key.json

multiplier2_0001.zkey: multiplier2_0000.zkey
	echo 'yyy' | snarkjs zkey contribute multiplier2_0000.zkey multiplier2_0001.zkey --name="1st Contributor Name" -v

multiplier2_0000.zkey: pot12_final.ptau multi.r1cs
	snarkjs groth16 setup multi.r1cs pot12_final.ptau multiplier2_0000.zkey

pot12_final.ptau:
	snarkjs powersoftau new bn128 12 pot12_0000.ptau -v
	echo 'xxx' | snarkjs powersoftau contribute pot12_0000.ptau pot12_0001.ptau --name="First contribution" -v
	snarkjs powersoftau prepare phase2 pot12_0001.ptau pot12_final.ptau -v

.PHONY: clean
clean:
	rm public.json
	rm -f *.wtns
	rm -f input.json
	rm -rf multi_js
	rm -f *.wasm
	rm -f *.ptau
	rm -f *.zkey
	rm -f verification_key.json
	rm -f proof.json

