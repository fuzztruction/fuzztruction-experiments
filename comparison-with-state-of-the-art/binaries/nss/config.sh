#!/usr/bin/env bash

set -eu

readonly ZIP_VERSION="3.0"
readonly ZIP_TARGET="zip-$ZIP_VERSION"
readonly UNZIP_VERSION="6.0"
readonly UNZIP_TARGET="unzip-$UNZIP_VERSION"
readonly LIBBZ2_VERSION="1.0"


function build_ft {
    mkdir -p inputs
    mkdir -p ft
    rm -rf ft/*

    cp -r src/* ft/
    pushd ft/

    export FT_HOOK_INS=store,load,select,icmp
    export CC=/home/user/fuzztruction/generator/pass/fuzztruction-source-clang-fast
    export CXX=/home/user/fuzztruction/generator/pass/fuzztruction-source-clang-fast++
    make -j -C nss nss_build_all USE_64=1 BUILD_OPT=1

    popd > /dev/null
}

function build_afl {
    mkdir -p afl
    rm -rf afl/*
    cp -r src/* afl/
    pushd afl/ > /dev/null

    export AFL_LLVM_LAF_SPLIT_SWITCHES=1
    export AFL_LLVM_LAF_TRANSFORM_COMPARES=1
    export AFL_LLVM_LAF_SPLIT_COMPARES=1
    export CC="afl-clang-fast"
    export CXX="afl-clang-fast++"
    make -j -C nss nss_build_all USE_64=1 BUILD_OPT=1

    popd > /dev/null
}

function build_symcc {
    mkdir -p symcc
    rm -rf symcc/*
    cp -r src/* symcc/
    pushd symcc/ > /dev/null

    export SYMCC_NO_SYMBOLIC_INPUT=yes
    export SYMCC_LIBCXX_PATH=/libcxx_symcc
    export CC="/symcc/symcc"
    export CXX="/symcc/sym++"
    make -j -C nss nss_build_all USE_64=1 BUILD_OPT=0

    popd > /dev/null
}

function build_afl_symcc {
    mkdir -p afl_symcc
    rm -rf afl_symcc/*
    cp -r src/* afl_symcc/
    pushd afl_symcc/ > /dev/null

    export AFL_LLVM_INSTRUMENT="CLASSIC"
    export AFL_MAP_SIZE=65536
    export AFL_LLVM_LAF_SPLIT_SWITCHES=1
    export AFL_LLVM_LAF_TRANSFORM_COMPARES=1
    export AFL_LLVM_LAF_SPLIT_COMPARES=1

    export CC="afl-clang-fast"
    export CXX="afl-clang-fast++"
    make -j -C nss nss_build_all USE_64=1 BUILD_OPT=1

    popd > /dev/null
}

function build_vanilla {
    mkdir -p vanilla
    rm -rf vanilla/*
    cp -r src/* vanilla/
    pushd vanilla/ > /dev/null

    export CC="clang"
    export CXX="clang++"

    make -j -C nss nss_build_all USE_64=1

    popd > /dev/null
}

function install_dependencies {
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get install mercurial -y
}

function get_source {
    mkdir -p src
    pushd src/
    [[ -d nspr ]] || hg clone https://hg.mozilla.org/projects/nspr || true
    [[ -d nss ]] || hg clone https://hg.mozilla.org/projects/nss || true
    popd
}
