#!/usr/bin/env bash

set -eu
set -o pipefail

function in_subshell () {
    (
        $1
    )
}

function check_config_exported_functions() {
    local failed=0
    for fn_name in "get_source install_dependencies build_ft build_afl build_symcc build_afl_symcc build_vanilla"; do
        if ! type $fn_name > /dev/null; then
            echo "[!] Target config does not define function $fn_name"
            failed=1
        fi
    done
    if [[ $failed -ne 0 ]]; then
        echo "[!] Config check failed! Please fix your config."
        exit 1
    fi
}

if [[ $# -lt 1 ]]; then
    echo "[!] Not enough arguments! TODO: <path> [mode]"
    exit 1
fi

path=$1
if [[ ! -d "$path" ]]; then
    echo "[!] Invalid directory: $path"
    exit 1
fi
cfg_path="$path/config.sh"
if [[ ! -f "$cfg_path" ]]; then
    echo "[!] Config could not be found at: $cfg_path"
    exit 1
fi

cd $path
source config.sh
check_config_exported_functions


mode=${2-"all"}
case $mode in
    source|src)
        in_subshell get_source
    ;;
    deps)
        in_subshell install_dependencies
    ;;
    ft)
        in_subshell build_ft
    ;;
    afl)
        # This binary will be used by WEIZZ as well
        in_subshell build_afl
    ;;
    symcc)
        in_subshell build_symcc
        in_subshell build_afl_symcc
    ;;
    vanilla)
        in_subshell build_vanilla
    ;;
    all)
        in_subshell get_source || true
        in_subshell install_dependencies || true
        in_subshell build_ft || true
        in_subshell build_afl || true
        in_subshell build_symcc || true
        in_subshell build_afl_symcc || true
        in_subshell build_vanilla || true
    ;;
    *)
        echo "[!] Invalid mode $mode"
        exit 1
    ;;
esac
