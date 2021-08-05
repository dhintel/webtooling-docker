# Set up an Ubuntu image with 'web tooling' installed

FROM ubuntu:20.04
LABEL maintainer="gang.g.li@intel.com"

ARG DEBIAN_FRONTEND=noninteractive

# Version of the Dockerfile
LABEL DOCKERFILE_VERSION="1.0"

# Please set proxy according to your network environment
# ENV http_proxy "http://proxy-chain.intel.com:911/"
# ENV https_proxy "http://proxy-chain.intel.com:912/"

# URL for web tooling test
ARG WEB_TOOLING_URL="https://github.com/v8/web-tooling-benchmark"
ARG NODEJS_VERSION="setup_14.x"

RUN apt-get update && \
	apt-get install -y build-essential git curl sudo && \
	apt-get remove -y unattended-upgrades && \
	curl -OkL https://deb.nodesource.com/${NODEJS_VERSION} && chmod +x ${NODEJS_VERSION} && ./${NODEJS_VERSION} && \
	apt-get install -y nodejs && \
	git clone ${WEB_TOOLING_URL} && \
	cd /web-tooling-benchmark/ && npm install --unsafe-perm

ARG BOLT

# Apply the optimized Node binary
COPY node.v14.thp.bolt.gz /web-tooling-benchmark

RUN \
	if [ "$BOLT" = "True" ]; then \
		cd /web-tooling-benchmark && mkdir bin && \
	    gzip -cd node.v14.thp.bolt.gz >bin/node && \
	    chmod +x bin/node && \
	    mv /usr/bin/node /usr/bin/node.v14.base && cp bin/node /usr/bin/ ; \
	fi

WORKDIR /web-tooling-benchmark

CMD ["node", "dist/cli.js"]
