#!/usr/bin/env bash

set -eu

function build_ft {
    mkdir -p ft
    mkdir -p qpdf-ft
    mkdir -p inputs
    rm -rf ft/*
    cp -r src/* ft/

    # build poppler
    pushd ft/poppler-* > /dev/null

    export FT_HOOK_INS=store,load,select,icmp
    export CC=/home/user/fuzztruction/generator/pass/fuzztruction-source-clang-fast
    sed -i "s@^\s*CC.*@CC=$CC@g" debian/rules
    export CXX=/home/user/fuzztruction/generator/pass/fuzztruction-source-clang-fast++
    sed -i "s@^\s*CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -g -fPIC -ldl"
    export DEB_CXXFLAGS_SET="-v -O3 -g -fPIC"
    export DEB_LDFLAGS_SET="-fPIC -ldl"

    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"
    dpkg-buildpackage --no-sign -jauto -b

    popd > /dev/null

    # build qpdf
    pushd ft/qpdf-* > /dev/null

    export FT_HOOK_INS=store,load,select,icmp
    export CC=/home/user/fuzztruction/generator/pass/fuzztruction-source-clang-fast
    sed -i "s@^\s*CC.*@CC=$CC@g" debian/rules
    export CXX=/home/user/fuzztruction/generator/pass/fuzztruction-source-clang-fast++
    sed -i "s@^\s*CXX.*@CXX=$CXX@g" debian/rules || true
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
    cp -r src/* afl/
    pushd afl/poppler-* > /dev/null

    export AFL_LLVM_LAF_SPLIT_SWITCHES=1
    export AFL_LLVM_LAF_TRANSFORM_COMPARES=1
    export AFL_LLVM_LAF_SPLIT_COMPARES=1

    export CC="afl-clang-fast"
    sed -i "s@^CC.*@CC=$CC@g" debian/rules
    export CXX="afl-clang-fast++"
    sed -i "s@^CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -fPIC -ldl"
    export DEB_CXXFLAGS_SET="-v -O3 -fPIC"
    export DEB_LDFLAGS_SET="-fPIC -ldl"

    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"
    dpkg-buildpackage --no-sign -jauto -b
    popd > /dev/null
}

function build_symcc {
    mkdir -p symcc
    rm -rf symcc/*
    cp -r src/* symcc/
    pushd symcc/poppler-* > /dev/null

    export SYMCC_NO_SYMBOLIC_INPUT=yes
    export SYMCC_LIBCXX_PATH=/libcxx_symcc
    export CC="/symcc/symcc"
    sed -i "s@^CC.*@CC=$CC@g" debian/rules
    export CXX="/symcc/sym++"
    sed -i "s@^CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -fPIC -ldl"
    export DEB_CXXFLAGS_SET="-v -O3 -fPIC"
    export DEB_LDFLAGS_SET="-fPIC -ldl"

    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"
    # fails because of dpkg-shlibdeps missing deps for custom std++
    dpkg-buildpackage --no-sign -jauto -b || true
    popd > /dev/null
}

function build_afl_symcc {
    mkdir -p afl_symcc
    rm -rf afl_symcc/*
    cp -r src/* afl_symcc/
    pushd afl_symcc/poppler-* > /dev/null

    export AFL_LLVM_INSTRUMENT="CLASSIC"
    export AFL_MAP_SIZE=65536
    export AFL_LLVM_LAF_SPLIT_SWITCHES=1
    export AFL_LLVM_LAF_TRANSFORM_COMPARES=1
    export AFL_LLVM_LAF_SPLIT_COMPARES=1

    export CC="afl-clang-fast"
    sed -i "s@^CC.*@CC=$CC@g" debian/rules
    export CXX="afl-clang-fast++"
    sed -i "s@^CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -fPIC -ldl"
    export DEB_CXXFLAGS_SET="-v -O3 -fPIC"
    export DEB_LDFLAGS_SET="-fPIC -ldl"

    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"
    dpkg-buildpackage --no-sign -jauto -b
    popd > /dev/null
}

function build_vanilla {
    mkdir -p vanilla
    rm -rf vanilla/*
    cp -r src/* vanilla/

    pushd vanilla/poppler-* > /dev/null
    export CC="clang"
    sed -i "s@^CC.*@CC=$CC@g" debian/rules
    export CXX="clang++"
    sed -i "s@^CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-g"
    export DEB_CXXFLAGS_SET="-g"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    dpkg-buildpackage --no-sign -jauto -b
    popd > /dev/null
}

function install_dependencies {
    export DEBIAN_FRONTEND=noninteractive
    sudo apt build-dep poppler-utils=0.86.1-0ubuntu1 qpdf -y
}

function get_source {
    mkdir -p src
    pushd src > /dev/null
    export DEBIAN_FRONTEND=noninteractive
    apt source poppler-utils=0.86.1-0ubuntu1 qpdf -y
    find -iname "*symbols.in*" -exec rm {} \;
    popd > /dev/null
}
