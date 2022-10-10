#!/usr/bin/env bash

set -eu

function build_ft {
    mkdir -p inputs
    mkdir -p ft
    rm -rf ft/*
    cp -r src/openssl ft/

    pushd ft/openssl > /dev/null
    export FT_HOOK_INS=store,load,select,icmp
    ./config -d shared no-threads
    sed -i 's/CC=$(CROSS_COMPILE)gcc.*/CC=\/home\/user\/fuzztruction\/generator\/pass\/fuzztruction-source-clang-fast/g' Makefile
    sed -i 's/CXX=$(CROSS_COMPILE)g++.*/CXX=\/home\/user\/fuzztruction\/generator\/pass\/fuzztruction-source-clang-fast++/g' Makefile
    sed -i 's/CFLAGS=.*/CFLAGS=-O3 -g -fPIC -DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION -DFT_STATIC_SEED/g' Makefile
    sed -i 's/CXXFLAGS=.*/CXXFLAGS=-O3 -g -fPIC -DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION -DFT_STATIC_SEED/g' Makefile
    LDCMD=clang++ make -j || true
    make -j
    popd > /dev/null
}

function build_afl {
    mkdir -p afl
    rm -rf afl/*
    cp -r src/openssl afl/

    pushd afl/openssl > /dev/null
    export AFL_LLVM_LAF_SPLIT_SWITCHES=1
    export AFL_LLVM_LAF_TRANSFORM_COMPARES=1
    export AFL_LLVM_LAF_SPLIT_COMPARES=1

    ./config -d shared no-threads
    sed -i 's/CC=$(CROSS_COMPILE)gcc.*/CC=afl-clang-fast/g' Makefile
    sed -i 's/CXX=$(CROSS_COMPILE)g++.*/CXX=afl-clang-fast++/g' Makefile
    sed -i 's/CFLAGS=.*/CFLAGS=-O3 -g -fPIC -DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION -DFT_STATIC_SEED/g' Makefile
    sed -i 's/CXXFLAGS=.*/CXXFLAGS=-O3 -g -fPIC -DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION -DFT_STATIC_SEED/g' Makefile
    bear make -j || true
    make
    popd > /dev/null
}

function build_afl_symcc {
    mkdir -p afl_symcc
    rm -rf afl_symcc/*
    cp -r src/openssl afl_symcc/

    pushd afl_symcc/openssl > /dev/null
    export AFL_LLVM_INSTRUMENT="CLASSIC"
    export AFL_MAP_SIZE=65536
    ./config -d shared no-threads
    sed -i 's/CC=$(CROSS_COMPILE)gcc.*/CC=afl-clang-fast/g' Makefile
    sed -i 's/CXX=$(CROSS_COMPILE)g++.*/CXX=afl-clang-fast++/g' Makefile
    sed -i 's/CFLAGS=.*/CFLAGS=-O3 -g -fPIC -DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION -DFT_STATIC_SEED/g' Makefile
    sed -i 's/CXXFLAGS=.*/CXXFLAGS=-O3 -g -fPIC -DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION -DFT_STATIC_SEED/g' Makefile
    bear make -j || true
    make
    popd > /dev/null
}

function build_symcc {
    mkdir -p symcc
    rm -rf symcc/*
    cp -r src/openssl symcc/

    pushd symcc/openssl > /dev/null
    ./config -d shared no-threads
    sed -i 's@CC=$(CROSS_COMPILE)gcc.*@CC=/symcc/symcc@g' Makefile
    sed -i 's@CXX=$(CROSS_COMPILE)g++.*@CXX=/symcc/sym++@g' Makefile
    sed -i 's/CFLAGS=.*/CFLAGS=-O3 -g -fPIC -DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION -DFT_STATIC_SEED/g' Makefile
    sed -i 's/CXXFLAGS=.*/CXXFLAGS=-O3 -g -fPIC -DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION -DFT_STATIC_SEED/g' Makefile
    bear make -j || true
    make
    popd > /dev/null
}

function build_vanilla {
    mkdir -p vanilla
    rm -rf vanilla/*
    cp -r src/openssl vanilla/
    pushd vanilla/openssl > /dev/null
    ./config -d shared no-threads
    make -j || true
    make
    popd > /dev/null
}

function install_dependencies {
    echo "No dependencies"
}

function get_source {
    mkdir -p src
    pushd src > /dev/null
    git clone --branch=OpenSSL_1_1_1l git://git.openssl.org/openssl.git || true
    popd > /dev/null
}
