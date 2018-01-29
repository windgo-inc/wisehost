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
}

function update_repo () {
    pushd "$1" &>/dev/null
    git pull origin master
    popd &>/dev/null
}

[[ ! -d emerald && ! -d emerald/.git ]] && get_emerald || update_repo emerald
[[ ! -d wise && ! -d wise/.git ]] && get_wise || {
    update_repo wise
    (cd wise && [[ `git status --porcelain --untracked-files=no` ]] && {
        rm -f wise && echo "Deleted old WISE executable." || echo "No old WISE executable." 
    })
}


