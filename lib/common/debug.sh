#!/usr/bin/env bash

_DEBUG=false

## Turns on debugging (`set -x`) and sets _DEBUG to true
##
## Arguments: none
## Usage: enable_debugging
## Return: none.
function enable_debugging() {
    set -x
    _DEBUG=true
}

## Turns off debugging (`set +x`) and sets _DEBUG to false
##
## Arguments: none
## Usage: disable_debugging
## Return: none.
function disable_debugging() {
    set +x
    _DEBUG=false
}

## Toggles the _DEBUG values by calling either `enable_debugging`
## or `disable_debugging`
##
## Arguments: none
##
## Usage:
##     toggle_debugging
##
## Return: none.
function toggle_debugging() {
    if [ "$_DEBUG" == false ]; then
        enable_debugging

    else
        disable_debugging
    fi
}
