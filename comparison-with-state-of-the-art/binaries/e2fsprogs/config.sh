#!/usr/bin/env bash

set -eu


function build_ft {
    mkdir -p inputs
    mkdir -p ft
    rm -rf ft/*

    # build fsutils
    cp -r src/e2fsprogs/* ft/
    pushd ft/e2fsprogs-* > /dev/null

    export FT_HOOK_INS=store,load,select,icmp
    export CC=/home/user/fuzztruction/generator/pass/fuzztruction-source-clang-fast
    sed -i "s@^CC.*@CC=$CC@g" debian/rules
    export CXX=/home/user/fuzztruction/generator/pass/fuzztruction-source-clang-fast++
    sed -i "s@^CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -g -fPIC -ldl"
    export DEB_CXXFLAGS_SET="-v -O3 -g -fPIC"
    export DEB_LDFLAGS_SET="-fPIC -ldl"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    dpkg-buildpackage --no-sign -jauto -b
    popd > /dev/null
}

function build_afl {
    mkdir -p afl
    rm -rf afl/*
    cp -r src/e2fsprogs/* afl/
    pushd afl/e2fsprogs-* > /dev/null

    export AFL_LLVM_LAF_SPLIT_SWITCHES=1
    export AFL_LLVM_LAF_TRANSFORM_COMPARES=1
    export AFL_LLVM_LAF_SPLIT_COMPARES=1

    # Remove custom signal catcher
    find "$PWD" -iname "*.c" -exec sed -i 's@\s*sigcatcher_setup();@/* sigcatcher_setup(); */@g' {} \;

    export CC="afl-clang-fast"
    sed -i "s@^CC.*@CC=$CC@g" debian/rules
    export CXX="afl-clang-fast++"
    sed -i "s@^CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -fPIC -g -ldl -DNO_EXCEPT_SIGNALS"
    export DEB_CXXFLAGS_SET="-v -O3 -fPIC -g -DNO_EXCEPT_SIGNALS"
    export DEB_LDFLAGS_SET="-fPIC -ldl"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    dpkg-buildpackage --no-sign -jauto -b
    popd > /dev/null
}

function build_afl_symcc {
    mkdir -p afl_symcc
    rm -rf afl_symcc/*
    cp -r src/e2fsprogs/* afl_symcc/
    pushd afl_symcc/e2fsprogs-* > /dev/null

    export AFL_LLVM_INSTRUMENT="CLASSIC"
    export AFL_MAP_SIZE=65536
    export AFL_LLVM_LAF_SPLIT_SWITCHES=1
    export AFL_LLVM_LAF_TRANSFORM_COMPARES=1
    export AFL_LLVM_LAF_SPLIT_COMPARES=1

    # Remove custom signal catcher
    find "$PWD" -iname "*.c" -exec sed -i 's@\s*sigcatcher_setup();@/* sigcatcher_setup(); */@g' {} \;

    export CC="afl-clang-fast"
    sed -i "s@^CC.*@CC=$CC@g" debian/rules
    export CXX="afl-clang-fast++"
    sed -i "s@^CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -fPIC -g -ldl -DNO_EXCEPT_SIGNALS"
    export DEB_CXXFLAGS_SET="-v -O3 -fPIC -g -DNO_EXCEPT_SIGNALS"
    export DEB_LDFLAGS_SET="-fPIC -ldl"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    dpkg-buildpackage --no-sign -jauto -b
    popd > /dev/null
}

function build_symcc {
    mkdir -p symcc
    rm -rf symcc/*
    cp -r src/e2fsprogs/* symcc/
    pushd symcc/e2fsprogs-* > /dev/null

    find "$PWD" -iname "*.c" -exec sed -i 's@\s*sigcatcher_setup();@/* sigcatcher_setup(); */@g' {} \;

    export SYMCC_NO_SYMBOLIC_INPUT=yes
    export CC="/symcc/symcc"
    sed -i "s@^CC.*@CC=$CC@g" debian/rules
    export CXX="/symcc/sym++"
    sed -i "s@^CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -fPIC -g -ldl -DNO_EXCEPT_SIGNALS"
    export DEB_CXXFLAGS_SET="-v -O3 -fPIC -g -DNO_EXCEPT_SIGNALS"
    export DEB_LDFLAGS_SET="-fPIC -ldl"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    dpkg-buildpackage --no-sign -jauto -b
    popd > /dev/null
}


function build_vanilla {
    mkdir -p vanilla
    rm -rf vanilla/*
    cp -r src/e2fsprogs/* vanilla/
    pushd vanilla/e2fsprogs-* > /dev/null

    find "$PWD" -iname "*.c" -exec sed -i 's@\s*sigcatcher_setup();@/* sigcatcher_setup(); */@g' {} \;

    export CC="clang"
    sed -i "s@^CC.*@CC=$CC@g" debian/rules
    export CXX="clang++"
    sed -i "s@^CXX.*@CXX=$CXX@g" debian/rules || true

    export DEB_CFLAGS_SET="-v -O3 -fPIC -g -ldl -DNO_EXCEPT_SIGNALS"
    export DEB_CXXFLAGS_SET="-v -O3 -fPIC -g -DNO_EXCEPT_SIGNALS"
    export DEB_LDFLAGS_SET="-fPIC -ldl"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    dpkg-buildpackage --no-sign -jauto -b
    popd > /dev/null
}

function build_asan {
    mkdir -p asan
    rm -rf asan/*
    mkdir -p asan
    cp -r src/e2fsprogs/* asan/
    pushd asan/e2fsprogs-* > /dev/null

    find "$PWD" -iname "*.c" -exec sed -i 's@\s*sigcatcher_setup();@/* sigcatcher_setup(); */@g' {} \;

    export AFL_MAP_SIZE=262144
    export AFL_LLVM_LAF_SPLIT_SWITCHES=1
    export AFL_LLVM_LAF_TRANSFORM_COMPARES=1
    export AFL_LLVM_LAF_SPLIT_COMPARES=1

    export CC="afl-clang-fast"
    sed -i "s@^CC.*@CC=$CC@g" debian/rules
    export CXX="afl-clang-fast++"
    sed -i "s@^CXX.*@CXX=$CXX@g" debian/rules || true

    export DEB_CFLAGS_SET="-v -O3 -fPIC -g -fsanitize=address"
    export DEB_CXXFLAGS_SET="-v -O3 -fPIC -g -fsanitize=address"
    export DEB_LDFLAGS_SET="-fPIC -lpthread -ldl -fsanitize=address"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    dpkg-buildpackage --no-sign -jauto -b
    popd > /dev/null
}

function install_dependencies {
    export DEBIAN_FRONTEND=noninteractive
    sudo apt build-dep e2fsprogs -y
}

function get_source {
    export DEBIAN_FRONTEND=noninteractive
    mkdir -p src
    # download e2fsprogs (source, sink)
    mkdir -p src/e2fsprogs
    pushd src/e2fsprogs > /dev/null
    apt source e2fsprogs -y
    popd > /dev/null
}
