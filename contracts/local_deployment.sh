#!/bin/bash

set -eu
set -o pipefail

# this is a entrypoint for a dockerized hardhat evm node
# it starts the hardhat node, runs our deployment scripts
# builds the required deployment confgiuration
# it is used for local development

_term() {
  echo "Terminated by user!"
  exit 1
}
trap _term SIGINT
trap _term SIGTERM

# remove the relay config so that relay
# waits until this deployment has completed
rm -f /config/*

# must match the value for the target hardhat networks
ACCOUNT_MNEMONIC="thunder road vendor cradle rigid subway isolate ridge feel illegal whale lens"

# set blocktime - sometimes it is useful to simulate slower mining
: ${MINER_BLOCKTIME:=0}

echo "+-------------------+"
echo "| starting evm node |"
echo "+-------------------+"
npx ganache ethereum \
	--miner.blockTime "${MINER_BLOCKTIME}" \
	--server.host 0.0.0.0 \
	--server.port 8545 \
	--database.dbPath /db/chain.db \
	--wallet.mnemonic "${ACCOUNT_MNEMONIC}" \
	--chain.chainId 31337 \
	--chain.networkId 31337 \
	--chain.allowUnlimitedContractSize \
	--chain.hardfork london \
	&

# wait for node to start
while ! curl -sf -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' localhost:8545 >/dev/null; do
	echo "waiting for evm node to start..."
	sleep 1
done

echo "+----------------------------+"
echo "| compiling hardhat project  |"
echo "+----------------------------+"
# npx hardhat compile --force --show-stack-traces

echo "+-----------------------------------+"
echo "| deploying primary chain contracts |"
echo "+-----------------------------------+"
#HARDHAT_NETWORK=localhost npx -- ts-node --transpileOnly ./scripts/deploy.ts

# copy the deployments config into shared volume
# cp deployments/*.json /config/

echo "+-------+"
echo "| ready |"
echo "+-------+"
echo ""


# wait and bail if either migration or evm node crash
wait -n
exit $?
