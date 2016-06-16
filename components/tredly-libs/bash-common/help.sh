#!/usr/bin/env bash

_HELP="usage -- Tredly script suite.

$(basename "$0") [COMMAND] [FLAGS] [SUBCOMMANDS...]

COMMAND        Name of the script in 'commands' folder to run
FLAGS          See options below
SUBCOMMANDS    Any number of space separated values which are to be consumed
               by the command

Commands:


Options:
    -h|--help|--usage       See help. Contextual to command.
    -d|--debug              Enables debug mode
    -v|--version            Displays version information
    --verbose               Enables verbose output

Examples:

"

## show_help($string, $force=false)
function show_help() {
    if [[ ("${_SHOW_HELP}" == true) || ("$2" == true) ]]; then
        echo "$(basename "$0"): $1"
        exit;
    fi
}
