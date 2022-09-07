
# groth16 setup requires lots of ram
export NODE_OPTIONS="--max-old-space-size=16000"

# .PHONY: verify
# verify: verification_key.json proof.json
# 	echo "---- inputs + outputs ----"
# 	jq . < input.json

verifier.sol: combat_0001.zkey
	npx snarkjs zkey export solidityverifier combat_0001.zkey $@

combat_js/combat.wasm: circuits/combat.circom
	rm -rf combat_js
	circom $< --wasm --sym

combat.r1cs: circuits/combat.circom
	rm -f combat.r1cs
	circom $< --r1cs

private.json: generate_inputs.js node_modules
	rm -f input.json $@
	node generate_inputs.js > $@
	echo "---- inputs ----"
	jq -c . < $@

node_modules: package.json
	npm install

witness.wtns: private.json combat_js/combat.wasm
	(cd combat_js && node generate_witness.js combat.wasm ../private.json ../$@)

input.json: private.json
	cp private.json input.json

proof.json: witness.wtns combat_0001.zkey input.json verification_key.json
	npx snarkjs groth16 prove combat_0001.zkey ./witness.wtns $@ ./input.json
	npx snarkjs groth16 verify verification_key.json input.json proof.json

verification_key.json: combat_0001.zkey
	npx snarkjs zkey export verificationkey $< $@

combat_0001.zkey: combat_0000.zkey
	echo 'yyy' | npx snarkjs zkey contribute $< $@ --name="1st Contributor Name" -v

combat_0000.zkey: pot18_final.ptau combat.r1cs
	npx snarkjs groth16 setup combat.r1cs $< $@

contracts/src/CombatVerifier.sol: verifier.sol
	sed <$< 's/0.6.11/0.8.11/g' >$@

################
# download a premade powers of tau suitable for up to 1M constraints
# it's a big file, see below for how to generate it instead
pot18_final.ptau:
	curl -o $@ https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_18.ptau
pot20_final.ptau:
	curl -o $@ https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_20.ptau
pot23_final.ptau:
	curl -o $@ https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_20.ptau
################
# Uncomment to generate the ptau instead of downloading it
# but it will take a while - like hours
######
# pot_0000.ptau:
# 	snarkjs powersoftau new bn128 20 $@ -v
# pot_0001.ptau: pot_0000.ptau
# 	echo 'xxx' | snarkjs powersoftau contribute $< $@ --name="First contribution" -v
# pot20_final.ptau: pot_0001.ptau
# 	snarkjs powersoftau prepare phase2 $< $@ -v

# Junk: does not work as expected
# contracts/src/MiMC.sol: contracts/src/MiMC.sol.tpl generate_mimc_contract.js
# 	sed 's/CONTRACT_BYTES/$(shell node generate_mimc_contract.js)/' <$< >$@
# contracts/src/Poseidon.sol: contracts/src/Poseidon.sol.tpl generate_poseidon_contract.js
# 	sed 's/CONTRACT_BYTES/$(shell node generate_poseidon_contract.js)/' <$< >$@

contracts/typechain-types/src/Alignment.sol:
	cd contracts && npx typechain \
		--target ethers-v5 \
		--out-dir ./typechain-types ./artifacts/contracts/Alignment.sol/Alignment.json

.PHONY: test
test: input.json proof.json contracts/src/CombatVerifier.sol
	(cd contracts && \
		MIMC_CONTRACT_BYTES=$(shell node generate_mimc_contract.js) \
		POSEIDON_CONTRACT_BYTES=$(shell node generate_poseidon_contract.js) \
		PROOF_INPUTS=$(shell cat input.json | jq -r '. | @csv' | sed 's/"//g') \
		PROOF_PI_A=$(shell cat proof.json| jq -r '.pi_a | @csv' | sed 's/"//g') \
		PROOF_PI_B_0=$(shell cat proof.json| jq -r '.pi_b[0] | @csv' | sed 's/"//g') \
		PROOF_PI_B_1=$(shell cat proof.json| jq -r '.pi_b[1] | @csv' | sed 's/"//g') \
		PROOF_PI_C=$(shell cat proof.json| jq -r '.pi_c | @csv' | sed 's/"//g') \
		forge test -vvv)
	(cd contracts && \
		npx hardhat test --bail)

contracts/broadcast/deploy.s.sol/31337/run-latest.json: contracts/src/CombatVerifier.sol
	(cd contracts && \
		POSEIDON_CONTRACT_BYTES=$(shell node generate_poseidon_contract.js) \
		forge script ./script/deploy.s.sol \
			--fork-url http://localhost:8545 \
			--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
			--broadcast)

.PHONY: deploy
deploy: contracts/broadcast/deploy.s.sol/31337/run-latest.json
	echo "$$(jq '.transactions[] | select(.transactionType == "CREATE") | {name: .contractName, address: .contractAddress}' < $<)"


.PHONY: clean
clean:
	rm -f private.json
	rm -f input.json
	rm -rf combat_js
	rm -f combat.r1cs combat.sym
	rm -f pot_0000.ptau pot_0001.ptau
	rm -f combat_0000.zkey combat_0001.zkey
	rm -f verification_key.json
	rm -f proof.json witness.wtns
	rm -f verifier.sol

