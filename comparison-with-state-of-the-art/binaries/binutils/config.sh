#!/usr/bin/env bash

set -eu

function build_ft {
    mkdir -p ft
    rm -rf ft/*
    cp -r src/binutils-2* ft/

    pushd ft/binutils-2* > /dev/null
    export FT_HOOK_INS=store,load,select,icmp
    export CC=/home/user/fuzztruction/generator/pass/fuzztruction-source-clang-fast
    sed -i "s@^\s*CC.*@CC=$CC@g" debian/rules
    export CXX=/home/user/fuzztruction/generator/pass/fuzztruction-source-clang-fast++
    sed -i "s@^\s*CXX.*@CXX=$CXX@g" debian/rules || true

    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    export DEB_CFLAGS_SET="-v -O3 -g -fPIC -ldl"
    sed -i "s@^CFLAGS.*@CFLAGS=$DEB_CFLAGS_SET@g" debian/rules

    export DEB_CXXFLAGS_SET="-v -O3 -g -fPIC"
    sed -i "s@^CXXFLAGS.*@CXXFLAGS=$DEB_CXXFLAGS_SET@g" debian/rules

    export DEB_LDFLAGS_SET="-fPIC -ldl"
    sed -i "s@^LDFLAGS.*@LDFLAGS=$DEB_LDFLAGS_SET@g" debian/rules

    sed -i "s@^CONFARGS = \\\.*@CONFARGS = --with-static-standard-libraries --disable-gdb --disable-gold --disable-ld \\\@g" debian/rules
    sed -i "s@.*--enable-shared.*@\\\@g" debian/rules
    sed -i "s@.*--with-system-zlib.*@\\\@g" debian/rules
    sed -i "s@.*--enable-threads.*@\\\@g" debian/rules

    dpkg-buildpackage --no-sign -jauto -b || true
    popd > /dev/null
}

function build_afl {
    mkdir -p afl
    rm -rf afl/*
    cp -r src/binutils-2* afl/

    pushd afl/binutils-2* > /dev/null
    export AFL_LLVM_LAF_SPLIT_SWITCHES=1
    export AFL_LLVM_LAF_TRANSFORM_COMPARES=1
    export AFL_LLVM_LAF_SPLIT_COMPARES=1

    export CC="afl-clang-fast"
    sed -i "s@^CC.*@CC=$CC@g" debian/rules
    export CXX="afl-clang-fast++"
    sed -i "s@^CXX.*@CXX=$CXX@g" debian/rules || true

    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    export DEB_CFLAGS_SET="-O3 -g -fPIC -ldl"
    sed -i "s@^CFLAGS.*@CFLAGS=$DEB_CFLAGS_SET@g" debian/rules

    export DEB_CXXFLAGS_SET="-O3 -g -fPIC"
    sed -i "s@^CXXFLAGS.*@CFLAGS=$DEB_CXXFLAGS_SET@g" debian/rules

    export DEB_LDFLAGS_SET="-fPIC -ldl"
    sed -i "s@^LDFLAGS.*@CFLAGS=$DEB_LDFLAGS_SET@g" debian/rules

    dpkg-buildpackage --no-sign -jauto -b
    popd > /dev/null
}

function build_afl_symcc {
    mkdir -p afl_symcc
    rm -rf afl_symcc/*
    cp -r src/binutils-2* afl_symcc/

    pushd afl_symcc/binutils-2* > /dev/null
    export AFL_LLVM_INSTRUMENT="CLASSIC"
    export AFL_MAP_SIZE=65536
    export AFL_LLVM_LAF_SPLIT_SWITCHES=1
    export AFL_LLVM_LAF_TRANSFORM_COMPARES=1
    export AFL_LLVM_LAF_SPLIT_COMPARES=1

    export CC="afl-clang-fast"
    sed -i "s@^CC.*@CC=$CC@g" debian/rules
    export CXX="afl-clang-fast++"
    sed -i "s@^CXX.*@CXX=$CXX@g" debian/rules || true

    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    export DEB_CFLAGS_SET="-O3 -g -fPIC -ldl"
    sed -i "s@^CFLAGS.*@CFLAGS=$DEB_CFLAGS_SET@g" debian/rules

    export DEB_CXXFLAGS_SET="-O3 -g -fPIC"
    sed -i "s@^CXXFLAGS.*@CFLAGS=$DEB_CXXFLAGS_SET@g" debian/rules

    export DEB_LDFLAGS_SET="-fPIC -ldl"
    sed -i "s@^LDFLAGS.*@CFLAGS=$DEB_LDFLAGS_SET@g" debian/rules

    dpkg-buildpackage --no-sign -jauto -b
    popd > /dev/null
}


function build_symcc {
    mkdir -p symcc
    rm -rf symcc/*
    cp -r src/binutils-2* symcc/

    pushd symcc/binutils-2* > /dev/null
    # used by symcc as tmp dir. Needed because of the tests
    # snippets executed by configure.
    mkdir -p /tmp/output

    export CC="/symcc/symcc"
    sed -i "s@^CC.*@CC=$CC@g" debian/rules
    export CXX="/symcc/sym++"
    sed -i "s@^CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    export DEB_CFLAGS_SET="-O3 -g -fPIC -ldl"
    sed -i "s@^CFLAGS.*@CFLAGS=$DEB_CFLAGS_SET@g" debian/rules

    export DEB_CXXFLAGS_SET="-O3 -g -fPIC"
    sed -i "s@^CXXFLAGS.*@CFLAGS=$DEB_CXXFLAGS_SET@g" debian/rules

    export DEB_LDFLAGS_SET="-fPIC -ldl"
    sed -i "s@^LDFLAGS.*@CFLAGS=$DEB_LDFLAGS_SET@g" debian/rules

    dpkg-buildpackage --no-sign -jauto -b || true
    popd > /dev/null
}

function build_vanilla {
    mkdir -p vanilla
    rm -rf vanilla/*
    cp -r src/binutils-2* vanilla/
    pushd vanilla/binutils-2* > /dev/null

    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    export DEB_CFLAGS_SET="-O3 -g -fPIC -ldl"
    sed -i "s@^CFLAGS.*@CFLAGS=$DEB_CFLAGS_SET@g" debian/rules

    export DEB_CXXFLAGS_SET="-O3 -g -fPIC"
    sed -i "s@^CXXFLAGS.*@CFLAGS=$DEB_CXXFLAGS_SET@g" debian/rules

    export DEB_LDFLAGS_SET="-fPIC -ldl"
    sed -i "s@^LDFLAGS.*@CFLAGS=$DEB_LDFLAGS_SET@g" debian/rules

    dpkg-buildpackage --no-sign -jauto -b
    popd > /dev/null
}

function install_dependencies {
    export DEBIAN_FRONTEND=noninteractive
    sudo apt build-dep binutils -y
}

function get_source {
    mkdir -p src
    pushd src > /dev/null
    export DEBIAN_FRONTEND=noninteractive
    apt source binutils -y
    popd > /dev/null
}
