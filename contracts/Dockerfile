FROM node:16.13.2-slim
RUN apt-get -y -qq update && \
	apt-get install -y -qq curl git jq python3 build-essential pkg-config libusb-1.0.0 libusb-1.0.0-dev libudev-dev g++ && \
	apt-get clean

# workdir
RUN mkdir -p /solidity
WORKDIR /solidity

# dependencies
ENV NODE_ENV=development
COPY package*.json ./
RUN	npm install

COPY src ./src
COPY lib ./lib
COPY scripts ./scripts
COPY remappings.txt ./
COPY hardhat.config.* ./
COPY tsconfig.json ./

ENV DOCKER=true
ENV NODE_ENV=production
COPY local_deployment.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD []

