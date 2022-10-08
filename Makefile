
# groth16 setup requires lots of ram
export NODE_OPTIONS="--max-old-space-size=16000"
export REPORT_GAS="true"
export CI="true"

.PHONY: verify
verify: verification_key.json proof.json
	echo "---- inputs + outputs ----"
	jq . < input.json

verifier.sol: combat_0001.zkey
	npx snarkjs zkey export solidityverifier $< $@

verifiernohash.sol: combatnohash_0001.zkey
	npx snarkjs zkey export solidityverifier $< $@

circuits/combatnohash.circom: circuits/combat.circom
	sed 's/<==/<--/g' <$< | sed 's/==>/-->/g' > $@

combatnohash_js/combatnohash.wasm: circuits/combatnohash.circom
	rm -rf combat_fast_js
	circom $< --wasm --sym

combatnohash.r1cs: circuits/combatnohash.circom circuits/templates.circom
	rm -f combatnohash.r1cs
	circom $< --r1cs

combat_js/combat.wasm: circuits/combat.circom circuits/templates.circom
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

# combat_0001.zkey: combat_0000.zkey
# 	echo 'yyy' | npx snarkjs zkey contribute $< $@ --name="1st Contributor Name" -v

combat_0001.zkey: pot18_final.ptau combat.r1cs
	npx snarkjs groth16 setup combat.r1cs $< $@

combatnohash_0001.zkey: combatnohash_0000.zkey
	echo 'yyy' | npx snarkjs zkey contribute $< $@ --name="1st Contributor Name" -v

combatnohash_0000.zkey: pot18_final.ptau combatnohash.r1cs
	npx snarkjs groth16 setup combatnohash.r1cs $< $@

contracts/src/CombatVerifier.sol: verifier.sol
	sed <$< 's/\^0.6.11/\^0.8.11/g' >$@

contracts/src/CombatNoHashVerifier.sol: verifiernohash.sol
	sed <$< 's/\^0.6.11/\^0.8.11/g' >$@

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

contracts/typechain-types/src/Alignment.sol:
	cd contracts && npx typechain \
		--target ethers-v5 \
		--out-dir ./typechain-types ./artifacts/contracts/Alignment.sol/Alignment.json

contracts/node_modules: contracts/package.json
	(cd contracts && npm install)

.PHONY: test
test: input.json proof.json contracts/src/CombatVerifier.sol contracts/src/CombatNoHashVerifier.sol combatnohash_js/combatnohash.wasm combatnohash_0001.zkey contracts/node_modules
	# (cd contracts && \
	# 	POSEIDON_CONTRACT_BYTES=$(shell node generate_poseidon_contract.js) \
	# 	PROOF_INPUTS=$(shell cat input.json | jq -r '. | @csv' | sed 's/"//g') \
	# 	PROOF_PI_A=$(shell cat proof.json| jq -r '.pi_a | @csv' | sed 's/"//g') \
	# 	PROOF_PI_B_0=$(shell cat proof.json| jq -r '.pi_b[0] | @csv' | sed 's/"//g') \
	# 	PROOF_PI_B_1=$(shell cat proof.json| jq -r '.pi_b[1] | @csv' | sed 's/"//g') \
	# 	PROOF_PI_C=$(shell cat proof.json| jq -r '.pi_c | @csv' | sed 's/"//g') \
	# 	forge test -vvv)
	(cd contracts && \
		npx hardhat test --bail)

.PHONY: deploy
deploy: input.json proof.json contracts/src/CombatVerifier.sol contracts/node_modules
	echo "deploying to localhost.... make sure your have a local anvil or ganache running"
	cd contracts && HARDHAT_NETWORK=localhost npx -- ts-node --transpileOnly ./scripts/deploy.ts


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

