
# groth16 setup requires lots of ram
export NODE_OPTIONS="--max-old-space-size=16000"

.PHONY: verify
verify: verification_key.json proof.json
	echo "---- inputs + outputs ----"
	jq . < input.json
	npx snarkjs groth16 verify verification_key.json input.json proof.json

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
	node generate_inputs.js 5 > $@
	echo "---- inputs ----"
	jq . < $@

node_modules: package.json
	npm install

witness.wtns: private.json combat_js/combat.wasm
	(cd combat_js && node generate_witness.js combat.wasm ../private.json ../$@)

input.json: private.json
	cp private.json input.json

proof.json: witness.wtns combat_0001.zkey input.json
	npx snarkjs groth16 prove combat_0001.zkey ./witness.wtns $@ ./input.json

verification_key.json: combat_0001.zkey
	npx snarkjs zkey export verificationkey $< $@

combat_0001.zkey: combat_0000.zkey
	echo 'yyy' | npx snarkjs zkey contribute $< $@ --name="1st Contributor Name" -v

combat_0000.zkey: pot18_final.ptau combat.r1cs
	npx snarkjs groth16 setup combat.r1cs $< $@

################
# download a premade powers of tau suitable for up to 1M constraints
# it's a big file, see below for how to generate it instead
pot18_final.ptau:
	curl -o $@ https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_18.ptau
pot20_final.ptau:
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

.PHONY: clean
clean:
	rm -f private.json
	rm -f input.json
	rm -rf combat_js
	rm -f combat.r1cs combat.sym
	rm -f pot_0000.ptau pot_0001.ptau
	rm -f combat_0000.zkey combat_0001.zkey
	rm -f verification_key.json
	rm -f proof.json
	rm -f verifier.sol

