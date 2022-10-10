

readonly ZIP_VERSION="16.02"
readonly ZIP_TARGET="p7zip-${ZIP_VERSION}+dfsg"
readonly LIBBZ2_VERSION="1.0"

function build_ft {
    mkdir -p inputs
    mkdir -p ft
    rm -rf ft/*

    # build 7zip
    cp -r src/7zip/* ft/
    pushd ft/$ZIP_TARGET > /dev/null

    # fix broken code
    sed -i "s/case E_/case (DWORD)E_/g" CPP/Windows/ErrorMsg.cpp
    sed -i "s/case STG_E_/case (DWORD)STG_E_/g" CPP/Windows/ErrorMsg.cpp
    export FT_HOOK_INS=store,load,select,icmp

    export CC=/home/user/fuzztruction/generator/pass/fuzztruction-source-clang-fast
    sed -i "s@^\s*CC.*@CC=$CC@g" debian/rules
    export CXX=/home/user/fuzztruction/generator/pass/fuzztruction-source-clang-fast++
    sed -i "s@^\s*CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -g -fPIC -ldl"
    export DEB_CXXFLAGS_SET="-v -O3 -g -fPIC"
    export DEB_LDFLAGS_SET="-fPIC -ldl"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    dpkg-buildpackage --no-sign --jobs=auto -b
    popd > /dev/null
}

function build_afl {
    mkdir -p afl
    rm -rf afl/*
    cp -r src/7zip/* afl/
    pushd afl/"$ZIP_TARGET" > /dev/null

    # fix broken code
    sed -i "s/case E_/case (DWORD)E_/g" CPP/Windows/ErrorMsg.cpp
    sed -i "s/case STG_E_/case (DWORD)STG_E_/g" CPP/Windows/ErrorMsg.cpp

    export CC="afl-clang-fast"
    sed -i "s@^\s*CC.*@CC=$CC@g" debian/rules
    export CXX="afl-clang-fast++"
    sed -i "s@^\s*CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -fPIC -ldl"
    export DEB_CXXFLAGS_SET="-v -O3 -fPIC"
    export DEB_LDFLAGS_SET="-fPIC -ldl"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    dpkg-buildpackage --no-sign --jobs=auto -b
    popd > /dev/null
}

function build_symcc {
    mkdir -p symcc
    rm -rf symcc/*
    cp -r src/7zip/* symcc/
    pushd symcc/"$ZIP_TARGET" > /dev/null

    # fix broken code
    sed -i "s/case E_/case (DWORD)E_/g" CPP/Windows/ErrorMsg.cpp
    sed -i "s/case STG_E_/case (DWORD)STG_E_/g" CPP/Windows/ErrorMsg.cpp

    export SYMCC_NO_SYMBOLIC_INPUT=yes
    export SYMCC_LIBCXX_PATH=/libcxx_symcc
    export CC="/symcc/symcc"
    sed -i "s@^\s*CC.*@CC=$CC@g" debian/rules
    export CXX="/symcc/sym++"
    sed -i "s@^\s*CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -fPIC -ldl"
    export DEB_CXXFLAGS_SET="-v -O3 -fPIC"
    export DEB_LDFLAGS_SET="-fPIC -ldl"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    # fails because of dpkg-shlibdeps missing deps for custom std++
    dpkg-buildpackage --no-sign --jobs=auto -b || true
    popd > /dev/null
}

function build_afl_symcc {
    mkdir -p afl_symcc
    rm -rf afl_symcc/*
    cp -r src/7zip/* afl_symcc/
    pushd afl_symcc/"$ZIP_TARGET" > /dev/null

    # fix broken code
    sed -i "s/case E_/case (DWORD)E_/g" CPP/Windows/ErrorMsg.cpp
    sed -i "s/case STG_E_/case (DWORD)STG_E_/g" CPP/Windows/ErrorMsg.cpp

    export AFL_LLVM_INSTRUMENT="CLASSIC"
    export AFL_MAP_SIZE=65536
    export CC="afl-clang-fast"
    sed -i "s@^\s*CC.*@CC=$CC@g" debian/rules
    export CXX="afl-clang-fast++"
    sed -i "s@^\s*CXX.*@CXX=$CXX@g" debian/rules || true
    export DEB_CFLAGS_SET="-v -O3 -fPIC -ldl"
    export DEB_CXXFLAGS_SET="-v -O3 -fPIC"
    export DEB_LDFLAGS_SET="-fPIC -ldl"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    dpkg-buildpackage --no-sign --jobs=auto -b
    popd > /dev/null
}


function build_vanilla {
    mkdir -p vanilla
    rm -rf vanilla/*
    cp -r src/7zip/* vanilla/
    pushd vanilla/"$ZIP_TARGET" > /dev/null

    # fix broken code
    sed -i "s/case E_/case (DWORD)E_/g" CPP/Windows/ErrorMsg.cpp
    sed -i "s/case STG_E_/case (DWORD)STG_E_/g" CPP/Windows/ErrorMsg.cpp
    export DEB_CFLAGS_SET="-g"
    export DEB_CXXFLAGS_SET="-g"
    export DEB_BUILD_OPTIONS="nodocs nostrip nocheck nomult nocross nohppa"

    bear dpkg-buildpackage --no-sign --jobs=auto -b
    popd > /dev/null
}

function install_dependencies {
    export DEBIAN_FRONTEND=noninteractive
    sudo apt build-dep p7zip=${ZIP_VERSION} -y
}

function get_source {
    mkdir -p src
    mkdir -p src/7zip
    pushd src/7zip > /dev/null
    export DEBIAN_FRONTEND=noninteractive
    apt source p7zip=${ZIP_VERSION} -y
    popd > /dev/null
}
