#!/usr/bin/env bash

################################
# WISE server bootstrap script.

shopt -s globstar

REQUIRED_NIM_VERSION="$1"
REQUIRED_REDIS_VERSION="$2"
BASE_DIRECTORY="$3"
SERVICE_DIRECTORY="${BASE_DIRECTORY}/$4"
BIN_DIRECTORY="${BASE_DIRECTORY}/$5"

mkdir -p "$BIN_DIRECTORY"
mkdir -p "$SERVICE_DIRECTORY"
cd "$BASE_DIRECTORY"

NIM_ARCHIVE_NAME="nim-${REQUIRED_NIM_VERSION}.tar.xz"
REDIS_ARCHIVE_NAME="redis-${REQUIRED_REDIS_VERSION}.tar.gz"

NIM_DOWNLOAD_URL="https://nim-lang.org/download/nim-${REQUIRED_NIM_VERSION}.tar.xz"
REDIS_DOWNLOAD_URL="https://github.com/antirez/redis/archive/${REQUIRED_REDIS_VERSION}.tar.gz"

function ensure_wget () {
    which wget &>/dev/null || {
        echo "Missing wget. Please install wget to bootstrap WISE, exit."
        exit 1
    }
}

function readlink_recursive () {
    local fname="$1"
    test -L "$fname" && readlink_recursive "$(readlink "$fname")" || echo "$fname"
}

function find_program () {
    while [ ! -z "$1" ]; do
        local trypath="$1"
        shift

        local program_name=$(which "$trypath" 2>/dev/null)
        [ -z "$program_name" ] || {
            echo "$program_name"
            #echo "$(readlink_recursive "$program_name")"
            break
        }
    done
}


# Search for needed programs
CC_PATH=$(find_program cc gcc)
NIMC_PATH=$(find_program "$BIN_DIRECTORY/nim") # Add system nim back in.
REDIS_PATH=$(find_program "$BIN_DIRECTORY/redis-server" redis-server)

function get_program_version () {
    which "$1" &>/dev/null && {
        "$1" -v 2>&1 | head -n1 | grep -Po '(?<='"$2"')[^ ]+'
    }
}

NIMC_VER=$(get_program_version "${NIMC_PATH}" 'Version ')
REDIS_VER=$(get_program_version "${REDIS_PATH}" 'server v=')

function should_get_program () {
    local program_path="$1"
    local required_version="$2"
    local actual_version="$3"
    [ -z "$1" ] && echo "0" || {
        #echo "Have ${program_path} version ${actual_version}, requiring ${required_version}." 1>&2
        [ "$required_version" == "$actual_version" ] && echo "1" || echo "0"
    }
}

function download_program () {
    pushd "${SERVICE_DIRECTORY}" &>/dev/null
    printf '%s' "Downloading $1..."
    [ -f ./"$2" ] && echo "already have $1." || {
        ensure_wget
        wget -O "$2" "$1" && echo " succeeded." || {
            echo " failed!"
            exit 1
        }
    }
    tar xf "$2" || {
        rm -f ./"$2"
        download_program "$1" "$2"
    }
    popd &>/dev/null
}

should_get_nim=$(should_get_program "${NIMC_PATH}" "${REQUIRED_NIM_VERSION}" "${NIMC_VER}")
should_get_redis=$(should_get_program "${REDIS_PATH}" "${REQUIRED_REDIS_VERSION}" "${REDIS_VER}")

[ "$should_get_nim" == "0" ] && {
    download_program "${NIM_DOWNLOAD_URL}" "${NIM_ARCHIVE_NAME}" 1>&2
    pushd "${SERVICE_DIRECTORY}/nim-${REQUIRED_NIM_VERSION}" &>/dev/null
        [ -f "bin/nimble" ] && echo "nim has already been built, skipping." 1>&2 || { 
            (sh build.sh && bin/nim c koch && ./koch tools) 1>&2
        }
    popd &>/dev/null
    pushd "${BIN_DIRECTORY}" &>/dev/null
        for tool in ../service/nim-${REQUIRED_NIM_VERSION}/bin/* ; do
            rm -f ./"$(basename "$tool")" 1>&2
            ln -s "$tool" ./"$(basename "$tool")" 1>&2
        done
    popd &>/dev/null
    NIMC_PATH=$(find_program "$BIN_DIRECTORY/nim" nim) # Add system nim back in.
}

[ "$should_get_redis" == "0" ] && {
    download_program "${REDIS_DOWNLOAD_URL}" "${REDIS_ARCHIVE_NAME}" 1>&2
    pushd "${SERVICE_DIRECTORY}/redis-${REQUIRED_REDIS_VERSION}" &>/dev/null
        [ -f "src/redis-server" ] && echo "redis has already been built, skipping." 1>&2 || {
            (make && make 'test') 1>&2
        }
    popd &>/dev/null
    pushd "${BIN_DIRECTORY}" &>/dev/null
        rm -f ./redis-server 1>&2
        ln -s "../service/redis-${REQUIRED_REDIS_VERSION}"/src/redis-server ./redis-server 1>&2
    popd &>/dev/null
    REDIS_PATH=$(find_program "$BIN_DIRECTORY/redis-server" redis-server)
}

NIMC_VER=$(get_program_version "${NIMC_PATH}" 'Version ')
REDIS_VER=$(get_program_version "${REDIS_PATH}" 'server v=')
NIMBLE_VER=$(get_program_version "${NIMC_PATH}ble" 'nimble v')

echo "Using nim version ${NIMC_VER}, @ path: ${NIMC_PATH}" 1>&2
echo "Using nimble version ${NIMBLE_VER}, @ path: ${NIMC_PATH}ble" 1>&2
echo "Using redis version ${REDIS_VER}, @ path: ${REDIS_PATH}" 1>&2

cd "${BASE_DIRECTORY}"
echo "
NIMC_PATH=\"${NIMC_PATH}\"
NIMBLE_PATH=\"${NIMC_PATH}ble\"
REDIS_PATH=\"${REDIS_PATH}\"
" > cached_paths.sh

