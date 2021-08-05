####################################################################
#                Developing container image                        #
#    Prepare optimized Node binary for 'web tooling' workload      #
####################################################################

FROM ubuntu:20.04 as build
#USER root

LABEL maintainer="gang.g.li@intel.com"
# Version of the Dockerfile
LABEL DOCKERFILE_VERSION="1.0"


ARG DEBIAN_FRONTEND=noninteractive

ENV TZ=America/Los_Angeles
# RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Please set proxy according to your network environment
#ENV http_proxy "http://proxy-chain.intel.com:911/"
#ENV https_proxy "http://proxy-chain.intel.com:912/"

# URL for web tooling test
ARG NODEJS_SRC="https://nodejs.org/download/release/v16.5.0/node-v16.5.0.tar.gz"
ARG LLVM_URL="https://github.com/llvm-mirror/llvm"
ARG LLVM_COMMIT="f137ed238db11440f03083b1c88b7ffc0f4af65e"
ARG BOLT_URL="https://github.com/facebookincubator/BOLT"
ARG BOLT_COMMIT="01f471e7108f04b66fd7d3689f3cae3ec8ff6449"


COPY 0001-Enables-Thansparent-hugepage-support-for-Node-js.patch /node/
COPY 0002-Enable-shorten-builtin-calls-v8-optimization.patch /node/
COPY perf_node_v16.5.0.data.gz /node/

RUN apt-get update && \
    apt-get install -y build-essential git curl sudo python3 autoconf \
    ca-certificates cmake ninja-build python libjemalloc-dev automake \
    ssh python3-dev python3-distutils wget python3-pip vim nano bison \
    gosu linux-tools-common linux-tools-`uname -r` &&\
    apt-get remove -y unattended-upgrades 

# Download Node.js source code, and apply THP patch
# Adjest the make -j[x] number, according to your machine spec
RUN cd /node/ && \
    curl -OkL ${NODEJS_SRC} && \
    tar zxvf node-v16.5.0.tar.gz && \
    cd node-v16.5.0 && \
    patch -p1 <../0001-Enables-Thansparent-hugepage-support-for-Node-js.patch && \
    patch -p1 <../0002-Enable-shorten-builtin-calls-v8-optimization.patch && \
    CC='gcc -no-pie -fno-PIE -Wl,--emit-relocs -Wl,-znow' \
      CXX='g++ -no-pie -fno-PIE -Wl,--emit-relocs -Wl,-znow' \
      ./configure \
        --openssl-no-asm \
        --experimental-enable-pointer-compression && \
    make -j36 && make install && \
    mkdir node_thp_sbc && make install PREFIX=./node_thp_sbc

#BOLT the built Node binary
RUN cd /node/ && git clone ${LLVM_URL} llvm && \
    cd llvm/tools &&\
    git checkout -b llvm-bolt ${LLVM_COMMIT} && \
    git clone ${BOLT_URL} llvm-bolt && \
    cd llvm-bolt && \
    git checkout -b oldmain ${BOLT_COMMIT} && \
    cd ../.. && \
    patch -p 1 < tools/llvm-bolt/llvm.patch && \
    cd .. && \
    mkdir build && cd build && \
    cmake -G Ninja ../llvm \
      -DLLVM_TARGETS_TO_BUILD="X86;AArch64" \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLVM_ENABLE_ASSERTIONS=ON && \
    ninja && \
    cd .. && gzip -d perf_node_v16.5.0.data.gz && \
    ./build/bin/llvm-bolt \
      /node/node-v16.5.0/node_thp_sbc/bin/node  \
      -o node.bolt \
      -p perf_node_v16.5.0.data \
      -reorder-blocks=cache+ \
      -reorder-functions=hfsort+ \
      -split-functions=3 \
      -split-all-cold \
      -split-eh \
      -dyno-stats \
      -skip-funcs=Builtins_.* \
      -ignore-build-id


####################################################################
#                Production container image                        #
#    Integrate optimized Node binary into 'web tooling' workload   #
####################################################################

FROM ubuntu:20.04
LABEL maintainer="gang.g.li@intel.com"

ARG DEBIAN_FRONTEND=noninteractive

# Version of the Dockerfile
LABEL DOCKERFILE_VERSION="1.0"

# Please set proxy according to your network environment
#ENV http_proxy "http://proxy-chain.intel.com:911/"
#ENV https_proxy "http://proxy-chain.intel.com:912/"

# URL for web tooling test
ARG WEB_TOOLING_URL="https://github.com/v8/web-tooling-benchmark"

COPY --from=build /node/node-v16.5.0/node_thp_sbc /usr/local/
COPY --from=build /node/node.bolt /node/

RUN apt-get update && \
    apt-get install -y git && \
    apt-get remove -y unattended-upgrades && \
    cp /node/node.bolt /usr/local/bin/node && \
    git clone ${WEB_TOOLING_URL} && \
    cd /web-tooling-benchmark/ && npm install --unsafe-perm

WORKDIR /web-tooling-benchmark
