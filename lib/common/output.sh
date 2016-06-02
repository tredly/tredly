#!/usr/bin/env bash

# all codes as per http://misc.flogisoft.com/bash/tip_colors_and_formatting
# Backgrounds
_backgroundDefault="\e[49m"
_backgroundBlack="\e[40m"
_backgroundRed="\e[41m"
_backgroundGreen="\e[42m"
_backgroundYellow="\e[43m"
_backgroundBlue="\e[44m"
_backgroundMagenta="\e[45m"
_backgroundCyan="\e[46m"
_backgroundLightGray="\e[47m"
_backgroundDarkGray="\e[100m"
_backgroundLightRed="\e[101m"
_backgroundLightGreen="\e[102m"
_backgroundLightYellow="\e[103m"
_backgroundLightBlue="\e[104m"
_backgroundLightMagenta="\e[105m"
_backgroundLightCyan="\e[106m"
_backgroundWhite="\e[107m"

# Formatting
_formatBold="\e[1m"
_formatDim="\e[2m"
_formatUnderline="\e[4m"
_formatBlink="\e[5m"
_formatInvert="\e[7m"
_formatHidden="\e[8m"
_formatReset="\e[0m\e[39m"

# Colours
_colourDefault="\e[39m"
_colourBlack="\e[30m"
_colourRed="\e[31m"
_colourOrange="\e[38;5;202m"
_colourGreen="\e[32m"
_colourYellow="\e[33m"
_colourBlue="\e[34m"
_colourMagenta="\e[35m"
_colourCyan="\e[36m"
_colourLightGray="\e[37m"
_colourDarkGray="\e[90m"
_colourLightRed="\e[91m"
_colourLightGreen="\e[92m"
_colourLightYellow="\e[93m"
_colourLightBlue="\e[94m"
_colourLightMagenta="\e[95m"
_colourLightCyan="\e[96m"
_colourWhite="\e[97m"


#
# Headers and Logging
#

function e_header() {
    #local _numChars=$(( ${#1} + 4 ))
    local _numChars=${#1}

    # print out the header
    printf "${_formatBold}${_colourMagenta}"
    seq  -f "=" -s '' ${_numChars}
    printf "\n%s\n" "$@"
    #seq  -f "=" -s '' ${_numChars}
    printf "${_formatReset}${_colourDefault}\n"
}
function e_arrow() {
    printf "➜ $@\n"
}
function e_error() {
    printf "${_colourRed}✖ Error: %s${_formatReset}${_colourDefault}\n" "$@"
}
function e_stderr() {
    >&2 echo "$@"
}

function e_warning() {
    printf "${_colourYellow}➜ %s${_formatReset}${_colourDefault}\n" "$@"
}
function e_underline() {
    printf "${_formatUnderline}${_formatBold}%s${_formatReset}${_colourDefault}\n" "$@"
}
function e_note() {
    printf "${_colourOrange}%s${_formatReset}${_colourDefault}\n" "$@"
}
function e_bold() {
    printf "${_formatBold}%s${_formatReset}${_colourDefault}\n" "$@"
}

function e_success() {
    printf "${_colourGreen}✔ %s${_formatReset}${_colourDefault}\n" "$@"
}

function e_verbose() {
    # only output debug lines if debuging is on
    if [[ "$_VERBOSE_MODE" == "true" ]]; then
        printf "${_colourYellow}%s${_colourDefault}\n" "$@"
    fi
}
