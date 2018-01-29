#!/usr/bin/env bash

which git || {
    echo "git is required to install the dependecies of wise."
}

[ ! -d emerald ] && {
    git clone https://github.com/windgo-inc/emerald.git
    (cd emerald && nimble develop) || exit $?
}

[ ! -d wise ] && {
    git clone https://github.com/windgo-inc/wise.git
    exit $?
}

