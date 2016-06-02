#!/usr/bin/env bash

## Exits the script, displaying message provided.
##
## Arguments:
##     1. String. Message to display
##
## Usage:
##     exit_with_error "zomg, something went wrong!"
##
##
## Return: none.
function exit_with_error() {
    e_error "$(basename "$0"): $1"
    exit 1;
}
