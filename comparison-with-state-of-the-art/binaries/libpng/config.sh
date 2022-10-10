#!/usr/bin/env bash

set -eu

function build_ft {
    mkdir -p inputs
    mkdir -p ft
    rm -rf ft/*
    cp -r src/libpng ft/
    pushd ft/libpng > /dev/null

    export FT_HOOK_INS=store,load,select,icmp
    export CC=/home/user/fuzztruction/generator/pass/fuzztruction-source-clang-fast
    export CXX=/home/user/fuzztruction/generator/pass/fuzztruction-source-clang-fast++
    export CFLAGS="-v -O3 -fPIC -ldl"
    export CXXFLAGS="-v -O3 -fPIC"
    export LDFLAGS="-fPIC -ldl"
    ./configure
    make -j
    pushd contrib/examples > /dev/null
    $CC pngtopng.c -Wl,-rpath $(readlink -f ../../.libs) -L $(readlink -f ../../.libs) -lpng16 -o pngtopng
    popd > /dev/null
    popd > /dev/null
}

function build_afl {
    mkdir -p afl
    rm -rf afl/*
    cp -r src/libpng afl/
    pushd afl/libpng > /dev/null

    export AFL_LLVM_LAF_SPLIT_SWITCHES=1
    export AFL_LLVM_LAF_TRANSFORM_COMPARES=1
    export AFL_LLVM_LAF_SPLIT_COMPARES=1
    export CC="afl-clang-fast"
    export CXX="afl-clang-fast++"
    export CFLAGS="-v -O3 -g -fPIC -ldl"
    export CXXFLAGS="-v -O3 -g -fPIC"

    ./configure
    make -j
    pushd contrib/examples > /dev/null
    $CC pngtopng.c -Wl,-rpath $(readlink -f ../../.libs) -L $(readlink -f ../../.libs) -lpng16 -o pngtopng
    popd > /dev/null

    popd > /dev/null
}

function build_symcc {
    mkdir -p symcc
    rm -rf symcc/*
    cp -r src/libpng symcc/
    pushd symcc/libpng > /dev/null

    export SYMCC_NO_SYMBOLIC_INPUT=yes
    export CC="/symcc/symcc"
    export CXX="/symcc/sym++"
    export CFLAGS="-v -O3 -g -fPIC -ldl"
    export CXXFLAGS="-v -O3 -g -fPIC"

    ./configure
    make -j
    pushd contrib/examples > /dev/null
    $CC pngtopng.c -Wl,-rpath $(readlink -f ../../.libs) -L $(readlink -f ../../.libs) -lpng16 -o pngtopng
    popd > /dev/null

    popd > /dev/null
}

function build_afl_symcc {
    mkdir -p afl_symcc
    rm -rf afl_symcc/*
    cp -r src/libpng afl_symcc/
    pushd afl_symcc/libpng > /dev/null

    export AFL_LLVM_INSTRUMENT="CLASSIC"
    export AFL_MAP_SIZE=65536
    export AFL_LLVM_LAF_SPLIT_SWITCHES=1
    export AFL_LLVM_LAF_TRANSFORM_COMPARES=1
    export AFL_LLVM_LAF_SPLIT_COMPARES=1
    export CC="afl-clang-fast"
    export CXX="afl-clang-fast++"
    export CFLAGS="-v -O3 -g -fPIC -ldl"
    export CXXFLAGS="-v -O3 -g -fPIC"

    ./configure
    make -j
    pushd contrib/examples > /dev/null
    $CC pngtopng.c -Wl,-rpath $(readlink -f ../../.libs) -L $(readlink -f ../../.libs) -lpng16 -o pngtopng
    popd > /dev/null

    popd > /dev/null
}

function build_vanilla {
    mkdir -p vanilla
    rm -rf vanilla/*
    cp -r src/libpng vanilla/
    pushd vanilla/libpng > /dev/null
    export CC="gcc"
    ./configure
    make -j
    pushd contrib/examples > /dev/null
    $CC pngtopng.c -Wl,-rpath $(readlink -f ../../.libs) -L $(readlink -f ../../.libs) -lpng16 -o pngtopng
    popd > /dev/null
    popd > /dev/null
}

function install_dependencies {
    echo "No dependencies"
}

function get_source {
    mkdir -p src
    pushd src > /dev/null
    git clone https://github.com/glennrp/libpng.git --depth 1 || true
    pushd libpng > /dev/null
    git checkout libpng16
    popd > /dev/null
    popd > /dev/null
}
