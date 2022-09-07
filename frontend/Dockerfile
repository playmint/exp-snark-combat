
# build
FROM node:16.13.2-slim as builder
RUN apt-get -y -qq update && \
	apt-get install -y -qq curl git jq python3 build-essential pkg-config libusb-1.0.0 libusb-1.0.0-dev libudev-dev g++ && \
	apt-get clean
WORKDIR /app

# dependencies
RUN mkdir -p /app
COPY ./package*.json /app/
RUN	npm install

# start
CMD ["npm", "run", "start"]
