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

    # build libbz2
    cp -r src/libbz2/* ft/
    pushd ft/bzip2-${LIBBZ2_VERSION}* > /dev/null

    export FT_HOOK_INS=store,load,select,icmp
    export CC=/home/user/fuzztruction/generator/pass/fuzztruction-source-clang-fast
    export CXX=/home/user/fuzztruction/generator/pass/fuzztruction-source-clang-fast++
    sed -i "s@^\s*CC.*@CC=$CC@g" debian/rules
    sed -i "s@^\s*CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -g -fPIC -ldl"
    export DEB_CXXFLAGS_SET="-v -O3 -g -fPIC"
    export DEB_LDFLAGS_SET="-fPIC -ldl"

    dpkg-buildpackage --no-sign -j -b
    popd > /dev/null

    # build zip
    cp -r src/zip/* ft/
    pushd ft/$ZIP_TARGET > /dev/null
    find "$PWD" -iname "*.c" -exec sed -i 's@.*signal(.*handler).*@/* signal call removed */@g' {} \;

    export FT_HOOK_INS=store,load,select,icmp
    export CC=/home/user/fuzztruction/generator/pass/fuzztruction-source-clang-fast
    sed -i "s@^CC.*@CC=$CC@g" debian/rules
    export CXX=/home/user/fuzztruction/generator/pass/fuzztruction-source-clang-fast++
    sed -i "s@^CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -g -fPIC -ldl"
    export DEB_CXXFLAGS_SET="-v -O3 -g -fPIC"
    export DEB_LDFLAGS_SET="-fPIC -ldl"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    dpkg-buildpackage --no-sign -j -b
    popd > /dev/null
}

function build_afl {
    mkdir -p afl
    rm -rf afl/*
    cp -r src/unzip/* afl/
    pushd afl/$UNZIP_TARGET > /dev/null
    find "$PWD" -iname "*.c" -exec sed -i 's@.*signal(.*handler).*@/* signal call removed */@g' {} \;

    export AFL_LLVM_LAF_SPLIT_SWITCHES=1
    export AFL_LLVM_LAF_TRANSFORM_COMPARES=1
    export AFL_LLVM_LAF_SPLIT_COMPARES=1

    export CC="afl-clang-fast"
    sed -i "s@^CC.*@CC=$CC@g" debian/rules
    export CXX="afl-clang-fast++"
    sed -i "s@^CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -fPIC -g -ldl -DNO_EXCEPT_SIGNALS"
    export DEB_CXXFLAGS_SET="-v -O3 -fPIC -g -DNO_EXCEPT_SIGNALS"
    export DEB_LDFLAGS_SET="-fPIC -ldl"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    dpkg-buildpackage --no-sign -j -b
    popd > /dev/null

    # build libbz2
    cp -r src/libbz2/* afl/
    pushd afl/bzip2-${LIBBZ2_VERSION}* > /dev/null

    export AFL_LLVM_LAF_SPLIT_SWITCHES=1
    export AFL_LLVM_LAF_TRANSFORM_COMPARES=1
    export AFL_LLVM_LAF_SPLIT_COMPARES=1

    export CC="afl-clang-fast"
    export CXX="afl-clang-fast++"
    sed -i "s@^\s*CC.*@CC=$CC@g" debian/rules
    sed -i "s@^\s*CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -fPIC -g -ldl -DNO_EXCEPT_SIGNALS"
    export DEB_CXXFLAGS_SET="-v -O3 -fPIC -g -DNO_EXCEPT_SIGNALS"
    export DEB_LDFLAGS_SET="-fPIC -ldl"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    dpkg-buildpackage --no-sign -j -b
    popd > /dev/null
}

function build_symcc {
    mkdir -p symcc
    rm -rf symcc/*
    cp -r src/unzip/* symcc/
    pushd symcc/$UNZIP_TARGET > /dev/null
    find "$PWD" -iname "*.c" -exec sed -i 's@.*signal(.*handler).*@/* signal call removed */@g' {} \;

    export SYMCC_NO_SYMBOLIC_INPUT=yes
    export SYMCC_LIBCXX_PATH=/libcxx_symcc
    export CC="/symcc/symcc"
    sed -i "s@^CC.*@CC=$CC@g" debian/rules
    export CXX="/symcc/sym++"
    sed -i "s@^CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -fPIC -g -ldl -DNO_EXCEPT_SIGNALS"
    export DEB_CXXFLAGS_SET="-v -O3 -fPIC -g -DNO_EXCEPT_SIGNALS"
    export DEB_LDFLAGS_SET="-fPIC -ldl"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    dpkg-buildpackage --no-sign -j -b
    popd > /dev/null

    # build libbz2
    cp -r src/libbz2/* symcc/
    pushd symcc/bzip2-${LIBBZ2_VERSION}* > /dev/null

    export SYMCC_NO_SYMBOLIC_INPUT=yes
    export SYMCC_LIBCXX_PATH=/libcxx_symcc
    export CC="/symcc/symcc"
    export CXX="/symcc/sym++"
    sed -i "s@^\s*CC.*@CC=$CC@g" debian/rules
    sed -i "s@^\s*CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -fPIC -g -ldl -DNO_EXCEPT_SIGNALS"
    export DEB_CXXFLAGS_SET="-v -O3 -fPIC -g -DNO_EXCEPT_SIGNALS"
    export DEB_LDFLAGS_SET="-fPIC -ldl"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    dpkg-buildpackage --no-sign -j -b
    popd > /dev/null
}

function build_afl_symcc {
    mkdir -p afl_symcc
    rm -rf afl_symcc/*
    cp -r src/unzip/* afl_symcc/
    pushd afl_symcc/$UNZIP_TARGET > /dev/null
    find "$PWD" -iname "*.c" -exec sed -i 's@.*signal(.*handler).*@/* signal call removed */@g' {} \;

    export AFL_LLVM_INSTRUMENT="CLASSIC"
    export AFL_MAP_SIZE=65536
    export AFL_LLVM_LAF_SPLIT_SWITCHES=1
    export AFL_LLVM_LAF_TRANSFORM_COMPARES=1
    export AFL_LLVM_LAF_SPLIT_COMPARES=1

    export CC="afl-clang-fast"
    sed -i "s@^CC.*@CC=$CC@g" debian/rules
    export CXX="afl-clang-fast++"
    sed -i "s@^CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -fPIC -g -ldl -DNO_EXCEPT_SIGNALS"
    export DEB_CXXFLAGS_SET="-v -O3 -fPIC -g -DNO_EXCEPT_SIGNALS"
    export DEB_LDFLAGS_SET="-fPIC -ldl"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    dpkg-buildpackage --no-sign -j -b
    popd > /dev/null

    # build libbz2
    cp -r src/libbz2/* afl_symcc/
    pushd afl_symcc/bzip2-${LIBBZ2_VERSION}* > /dev/null

    export AFL_LLVM_INSTRUMENT="CLASSIC"
    export AFL_MAP_SIZE=65536
    export AFL_LLVM_LAF_SPLIT_SWITCHES=1
    export AFL_LLVM_LAF_TRANSFORM_COMPARES=1
    export AFL_LLVM_LAF_SPLIT_COMPARES=1

    export CC="afl-clang-fast"
    export CXX="afl-clang-fast++"
    sed -i "s@^\s*CC.*@CC=$CC@g" debian/rules
    sed -i "s@^\s*CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -fPIC -g -ldl -DNO_EXCEPT_SIGNALS"
    export DEB_CXXFLAGS_SET="-v -O3 -fPIC -g -DNO_EXCEPT_SIGNALS"
    export DEB_LDFLAGS_SET="-fPIC -ldl"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    dpkg-buildpackage --no-sign -j -b
    popd > /dev/null
}

function build_vanilla {
    mkdir -p vanilla
    rm -rf vanilla/*
    cp -r src/unzip/* vanilla/
    pushd vanilla/$UNZIP_TARGET > /dev/null
    find "$PWD" -iname "*.c" -exec sed -i 's@.*signal(.*handler).*@/* signal call removed */@g' {} \;

    export CC="clang"
    sed -i "s@^CC.*@CC=$CC@g" debian/rules
    export CXX="clang++"
    sed -i "s@^CXX.*@CXX=$CXX@g" debian/rules || true

    export DEB_CFLAGS_SET="-v -O3 -fPIC -g -ldl -DNO_EXCEPT_SIGNALS"
    export DEB_CXXFLAGS_SET="-v -O3 -fPIC -g -DNO_EXCEPT_SIGNALS"
    export DEB_LDFLAGS_SET="-fPIC -ldl"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    dpkg-buildpackage --no-sign -j -b
    popd > /dev/null
}

function install_dependencies {
    export DEBIAN_FRONTEND=noninteractive
    # zip (source)
    sudo apt build-dep zip=${ZIP_VERSION} -y
    # unzip (sink)
    sudo apt build-dep unzip=${UNZIP_VERSION} -y
    # libbz2 (library used for compression)
    sudo apt build-dep libbz2-1.0=${LIBBZ2_VERSION} -y
}

function get_source {
    mkdir -p src
    # download zip (source)
    mkdir -p src/zip
    pushd src/zip > /dev/null
    export DEBIAN_FRONTEND=noninteractive
    apt source zip=${ZIP_VERSION} -y
    popd > /dev/null
    # download unzip (sink)
    mkdir -p src/unzip
    pushd src/unzip > /dev/null
    apt source unzip=${UNZIP_VERSION} -y
    popd > /dev/null
    # download libbz2 (library used for compression)
    mkdir -p src/libbz2
    pushd src/libbz2 > /dev/null
    apt source libbz2-1.0=${LIBBZ2_VERSION} -y
    popd > /dev/null
}
