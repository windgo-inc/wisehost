#!/usr/bin/env bash

which git || {
    echo "git is required to install the dependecies of wise."
}

function get_emerald () {
    git clone https://github.com/windgo-inc/emerald.git
    (cd ~/.nimble/pkgs && rm -rf 'emerald-#head')
    (cd emerald && nimble develop) || {
        exit $?
    }
}

function get_wise () {
    git clone https://github.com/windgo-inc/wise.git
    exit $?
}

[ ! -d emerald ] && get_emerald
[ ! -d emerald/.git ] && get_emerald

[ ! -d wise ] && get_wise
[ ! -d wise/.git ] && get_wise

