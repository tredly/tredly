#!/usr/bin/env bash

function str_to_lower() {
    local _string=${1}

    echo ${_string,,}
}

# cmn_init
#
# Should be called at the beginning of every shell script.
#
# Exits your script if you try to use an uninitialised variable and exits your
# script as soon as any statement fails to prevent errors snowballing into
# serious issues.
#
# Example:
# cmn_init
#
# See: http://www.davidpashley.com/articles/writing-robust-shell-scripts/
#
function cmn_init {
    # Will exit script if we would use an uninitialised variable:
    set -o nounset
    # Will exit script when a simple command (not a control structure) fails:
    set -o errexit

    set -o errtrace
}

# cmn_assert_running_as_root
#
# Makes sure that the script is run as root. If it is, the function just
# returns; if not, it prints an error message and exits with return code 1 by
# calling `cmn_die`.
#
# Example:
# cmn_assert_running_as_root
#
# Note that this function uses variable $EUID which holds the "effective" user
# ID number; the EUID will be 0 even though the current user has gained root
# priviliges by means of su or sudo.
#
# See: http://www.linuxjournal.com/content/check-see-if-script-was-run-root-0
#
function cmn_assert_running_as_root {
  if [[ ${EUID} -ne 0 ]]; then
    exit_with_error "This script must be run as root!"
  fi
}

## returns whether or not a string is an int
##
## Arguments:
##     1. Value to test against
##
## Usage:
##     if is_int "1234"; then echo 'yes!'; else echo 'no!'; fi
##
## Return:
##     bool
function is_int() {
    local re='^[0-9]+$'
    if ! [[ "${1}" =~ ${re} ]] ; then
        return $E_ERROR
    fi

    return $E_SUCCESS
}

function is_float() {
    local re='^[0-9]*\.?[0-9]+$'
    if ! [[ "${1}" =~ ${re} ]] ; then
        return $E_ERROR
    fi

    return $E_SUCCESS
}

## Strips characters from the right side of a string
##
## Arguments:
##     1. String. The input to operate on
##     2. Optional. Characters to remove from the string. Defaults to space.
##
## Usage:
##     rtrim "input string!" "!"
##     rtrim "a string with spaces      "
##
## Return:
##     string
function rtrim() {
    # Default to using space
    local delim=" "

    local input="${1}"

    ## Use the 2nd param as delimiter if it was passed
    if [ -n "${2}" ]; then
        delim="${2}"
    fi

    shopt -s extglob
    echo "${input%%+(${delim})}"
    return ${E_SUCCESS}
}

## Strips characters from the left side of a string
##
## Arguments:
##     1. String. The input to operate on
##     2. Optional. Characters to remove from the string. Defaults to space.
##
## Usage:
##     ltrim "!!input string" "!"
##     ltrim "    a string with spaces"
##
## Return:
##     string
function ltrim() {
    # Default to using space
    local delim=" "

    local input="${1}"

    ## Use the 2nd param as delimiter if it was passed
    if [ -n "${2}" ]; then
        delim="${2}"
    fi

    shopt -s extglob
    echo "${input##+(${delim})}"
    return ${E_SUCCESS}
}

function str_replace() {

    local input="${1}"
    local needle="${2}"
    local replacement="${3}"

    ## Handle when input is an empty string.
    if [ -z "${input}" ]; then
        echo ""
        return $E_SUCCESS
    fi


    echo "${input//$needle/$replacement}"

    return $E_SUCCESS
}

## Strips characters from the start and end if a string
##
## Arguments:
##     1. String. The input to operate on
##     2. Optional. Characters to remove from the string. Defaults to space.
##
## Usage:
##     trim "!!input string!!!" "!"
##     trim "    a string with spaces     "
##
## Return:
##     string
function trim() {
    # Default to using space
    local delim=" "

    local input="${1}"

    local trimmed

    ## Use the 2nd param as delimiter if it was passed
    if [ -n "${2}" ]; then
        delim=${2}
    fi

    trimmed=$(rtrim "${input}" "${delim}")
    trimmed=$(ltrim "${trimmed}" "${delim}")

    echo "${trimmed}"

    return $E_SUCCESS
}

function create_dir() {
    local path="${1}"

    if [[ -d "${path}" ]]; then
        e_warning "Path \`${path}\` already exists. Skipping."
        return $E_SUCCESS
    fi

    mkdir -p "${path}"

    if [[ ! -d "${path}" ]]; then
        e_error "Unable to create folder ${path}"
        return $E_ERROR
    fi

    e_success "Created ${path}"
    return $E_SUCCESS
}

function max() {
    if [ "${1}" -gt "${2}" ]; then
        echo "${1}"
    else
        echo "${2}"
    fi

    return $E_SUCCESS
}

function min() {
    if [ "${1}" -lt "${2}" ]; then
        echo "${1}"
    else
        echo "${2}"
    fi

    return $E_SUCCESS
}

function copy_files() {
    local src=$(trim "${1}")
    local dest=$(trim "${2}")

    # be nice to the user and create any directories for them if necessary
    local _destDir
    if [[ "${dest}" =~ /$ ]]; then
        _destDir="${dest}"
    else
        _destDir=$(dirname "${dest}")
    fi


    if [[ ! -d "${_destDir}" ]]; then
        e_verbose "Creating folder ${_destDir}"
        mkdir -p "${_destDir}" 2> /dev/null
        if [[ $? -ne $E_SUCCESS ]]; then
            e_error "Failed to create folder \`${_destDir}\` to copy \`${src}\` into"
        fi
    fi

    # copy the file
    cp -R "${src}" "${dest}" 2> /dev/null

    if [[ $? -ne $E_SUCCESS ]]; then
        e_error "Unable to copy \`${src}\` to \`${dest}\`"
        return $E_ERROR
    fi

    e_verbose "Copied \`${src}\` to \`${dest}\`"
    return $E_SUCCESS
}

function is_os() {
    if [[ "${OSTYPE}" == $1* ]]; then
        return $E_SUCCESS
    fi
    return $E_ERROR
}

function type_exists() {
    if [ $(type -P $1) ]; then
        return $E_SUCCESS
    fi
    return $E_ERROR
}

## Takes a string and makes it ready for use in a regular expression
## (escapes anything that is not letter, number, underscore or hyphen)
##
## Arguments:
##     1. String. The input to operate on
##
## Usage:
##     regex_escape "10.0.1.1" -> outputs "10\.0\.1\.1"
##
## Return:
##     string
function regex_escape() {
    echo "${1}" | sed 's/[^[:alnum:]_-]/\\&/g'
    return $E_SUCCESS
}

## Takes an integer representing seconds. It then counds from 1 to
## that number sleeping for 1 second each time. Echos a period (.)
## each time as a form of "progress"
##
## Arguments:
##     1. Integer. Number of seconds to sleep for
##
## Usage:
##     sleep_with_progress 5
##
## Return:
##     none
function sleep_with_progress() {
    local t=$(trim "${1}")

    for (( c=1; c<="${t}"; c++ ))
    do
        sleep "${c}"
        printf "."
    done

    printf "\n"
    return $E_SUCCESS
}

## Removes all lines containing $containing from $file, where $file is the full path to the file
function remove_lines_from_file() {
    local file="${1}"
    local containing="${2}"
    local deleteEmptyFile="${3}"

    # check if the file actually exists
    if [[ -e "${file}" ]]; then
        # remove any lines containing $containing
        eval "sed -i '' '/${containing}/d' '${file}'"

        # if we arent removing the file then return
        if [[ "${deleteEmptyFile}" != "true" ]]; then
            return $E_SUCCESS
        fi
    else
        return $E_ERROR
    fi

    # check if the user wanted to delete the file if it is empty
    if [[ "${deleteEmptyFile}" == "true" ]]; then
        delete_file_if_empty "${file}"
        return $E_SUCCESS
    fi
}

# Deletes a file if it is empty (ingores whitespace)
function delete_file_if_empty() {
    local file="${1}"

    # get a copy of the file, removing all whitespace/newline characters
    local fileContents=$(cat ${file} | tr -d " \t\n\r")

    # check if it is empty
    if [[ -z "${fileContents}" ]]; then
        e_verbose "Removing empty file ${file}"
        eval "rm -f ${file}"
    fi
}

## generates a random uuid with x chars
## 8 is the default
function generate_short_uuid() {
    local X=${1}
    local _validChars=abcdefghijklmnopqrstuvwxyz1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ

    if [[ -z ${X} ]]; then
        X=8
    fi

    # get a random string
    for (( N=0; N < ${X}; ++N ))
    do
        echo -n ${_validChars:RANDOM%${#_validChars}:1}
    done

}

## generates a random uuid
function generate_uuid() {
    local N B C='89ab'
    for (( N=0; N < 16; ++N ))
    do
        B=$(( $RANDOM%256 ))

        case $N in
            6)
                printf '4%x' $(( B%16 ))
                ;;
            8)
                printf '%c%x' ${C:$RANDOM%${#C}:1} $(( B%16 ))
                ;;
            3 | 5 | 7 | 9)
                printf '%02x-' $B
                ;;
            *)
                printf '%02x' $B
                ;;
        esac
    done

    echo
}

# adds a line of data after a given string
function add_line_to_file_after_string() {
    local _data="${1}"
    local _needle="${2}"
    local _file="${3}"

    # escape the regexs
    _data="$(echo "${_data}" | sed -e 's/[]\/$*.^|[]/\\&/g')"
    _needle="$(echo "${_needle}" | sed -e 's/[]\/$*.^|[]/\\&/g')"

    # add in the data as well as a newline - note that '$'\n inserts a line break
    sed -i '' 's|'"${_needle}"'|&\'$'\n'"${_data}"'|g' "${_file}"

    return $?
}

# adds a line of data immediately after a given string provided it doesnt already exist
function add_line_to_file_between_strings_if_not_exists() {
    local _startNeedle="${1}"
    local _data="${2}"
    local _endNeedle="${3}"
    local _file="${4}"

    # check if it exists between the strings
    local fileData="$(cat "${_file}")"
    local dataBetween="$(get_data_between_strings "${_startNeedle}" "${_endNeedle}" "${fileData}")"

    local searchedDataBetween="$(echo "${dataBetween}" | grep -F "${_data}")"

    # check if it  exists between those strings
    if [[ -z "${searchedDataBetween}"  ]]; then
        # not found so add it in
        add_line_to_file_after_string "${_data}" "${_startNeedle}" "${_file}"

        return $?
    fi

    return ${E_SUCCESS}
}


# adds data to the start of a file
function add_data_to_start_of_file() {
    local _data="${1}"
    local _file="${2}"

    # check if the file has data in it or not - this affects how we add the data in
    if [[ -s "${_file}" ]]; then
        eval "sed -i '' -e '1i\'$'\n''${_data}' '${_file}'"
    else
        echo "${_data}" > "${_file}"
    fi
    return $?
}

# Adds data to the start of a given file if it was not found within the file
function add_data_to_start_of_file_if_not_exists() {
    local _data="${1}"
    local _file="${2}"

    local numLines=$(cat "${_file}" | grep "${_data}" | wc -l)

    # add it if it doesnt exist
    if [[ ${numLines} -eq 0 ]]; then

        $( add_data_to_start_of_file "${_data}" "${_file}" )

        return $?
    fi

    return $E_ERROR
}

## returns data between two given strings
function get_data_between_strings() {
    local _startString="${1}"
    local _endString="${2}"
    local _haystack="${3}"

    # make sure our startstring exists
    if [[ -z $( echo "${_haystack}" | grep "${_startString}") ]]; then
        echo ""
        return ${E_ERROR}
    fi

    # strip before startstring
    _haystack=${_haystack##*${_startString}}
    # strip after endstring
    _haystack=${_haystack%%${_endString}*}

    echo "${_haystack}"
    return ${E_SUCCESS}
}

# Trims whitespace
function strip_whitespace() {
    local _data="${1}"

    echo "${_data}" | tr -d '\040\011\012\015'
}

# deletes data between two given strings, as well as the strings themselves
function delete_data_from_file_between_strings_inclusive() {
    local _startString="${1}"
    local _endString="${2}"
    local _file="${3}"

    # escape any characters we need to keep in the given strings
    _startString=$(echo ${_startString} | sed -e 's/[]\/$*.^|[]/\\&/g')
    _endString=$(echo "${_endString}" | sed -e 's/[]\/$*.^|[]/\\&/g')

    sed -r -i "" "/${_startString}/,/.*${_endString}/d" "${_file}"
}

# takes a string and delimiter, and returns everything from the string on the right of the delimiter
# eg string = "api.tredly.com/mydirectory/", delimiter="/"
# output="api.tredly.com"
function rcut() {
    local _input="${1}"
    local _delimiter="${2}"

    echo "${_input#*${_delimiter}}"
}

# takes a string and delimiter, and returns everything from the string on the left of the delimiter
# eg string = "api.tredly.com/mydirectory/", delimiter="/"
# output="mydirectory/"
function lcut() {
    local _input="${1}"
    local _delimiter="${2}"

    echo "${_input%%${_delimiter}*}"
}

# returns true if _char is found in _input, false otherwise
function string_contains_char() {
    local _input="${1}"
    local _char="${2}"

    if echo "${_input}" | grep -q "${_char}"; then
        return ${E_SUCCESS}
    else
        return ${E_ERROR}
    fi
}

# Search an array for a given (sub)string
function array_contains_substring() {
    declare -a _array=("${!1}")
    local _needle="${2}"

    local e

    for e in "${_array[@]}"; do
        [[ "$e" =~ ${_needle} ]] && return ${E_SUCCESS}
    done
    return ${E_ERROR}
}

# takes a string of comma separated key=value pairs and returns the value for the given key
function extract_value_from_csv() {
    local _key="${1}"
    local _string="${2}"

    # loop over the key value pairs looking for our key
    IFS=','
    for keyValue in ${_string}
    do
        if [[ "$keyValue" =~ ^"${_key}=" ]]; then
            # found it, so extract the key and return
            echo $(rcut "${keyValue}" '=')

            return $E_SUCCESS
        fi
    done

    return $E_ERROR
}

# trims a given string from the end of another string
function remove_string_from_end_of_string() {
    local _needle="${1}"
    local _haystack="${2}"

    _needle=$( regex_escape "${_needle}" )
    echo  "${_haystack%${_needle}}"

    return $?
}


#flattens an array into a string, with elements separated by a given char
function array_flatten() {
    local _glue
    declare -a _array=("${!1}")

    if [[ -n "${2}" ]]; then
        _glue="${2}"
    else
        _glue=','
    fi

    (IFS=${_glue}; echo "${_array[*]}")

}

# creates a container name
function make_container_dirname() {
    local _containerGroupName="${1}"
    local _containerName="${2}"
    local _env="${3}"

    # if there was no group name or group version then set the container name appropriately
    if [[ -z "${_containerGroupName}" ]]; then
        echo "${_containerName}_${_env}"
    else
        echo "${_containerGroupName}_${_containerName}_${_env}"
    fi

    return $E_SUCCESS
}

# converts seconds to days hours minutes
function show_time() {
    num=$1
    min=0
    hour=0
    day=0
    if((num>59)); then
        ((sec=num%60))
        ((num=num/60))
        if((num>59)); then
            ((min=num%60))
            ((num=num/60))
            if((num>23)); then
                ((hour=num%24))
                ((day=num/24))
            else
                ((hour=num))
            fi
        else
            ((min=num))
        fi
    else
        ((sec=num))
    fi

    # only output the values if they were > 0
    if [[ ${day} -gt 0 ]]; then
        printf "%d days " ${day}
    fi
    if [[ ${hour} -gt 0 ]]; then
        printf "%d hours " ${hour}
    fi
    if [[ ${min} -gt 0 ]]; then
        printf "%d minutes " ${min}
    fi
    if [[ ${sec} -gt 0 ]]; then
        printf "%d seconds " ${sec}
    fi

}

# checks a string and returns whether or not it is a uuid
function is_uuid() {
    local _string="${1}"

    # search for the string within the host_uuid param
    local _numFound=$( zfs list -H -o name -r ${ZFS_TREDLY_PARTITIONS_DATASET} | grep "^${ZFS_TREDLY_PARTITIONS_DATASET}/.*/${TREDLY_CONTAINER_DIR_NAME}/${_string}$" | wc -l )

    # only return success if we found exactly 1
    if [[ ${_numFound} -eq 1 ]]; then
        return ${E_SUCCESS}
    fi

    return ${E_ERROR}
}

# replaces a line in a given file with the new given line
# handy for config files. Takes regex as arguments
function replace_line_in_file() {
    local _needle="${1}"
    local _replacement="${2}"
    local _file="${3}"

    sed -i '' "s|${_needle}|${_replacement}|g" "${_file}"

    return $?
}

# converts a value such as 32G (32 gigabytes) into the given type
function convert_size_unit() {
    local _fromString="${1}"
    local _convertToUnit="${2}"

    local _fromUnit="${_fromString: -1}"
    local _fromValue="${_fromString%?}"

    # convert the units to lowercase
    _fromUnit=$( str_to_lower "${_fromUnit}" )
    _convertToUnit=$( str_to_lower "${_convertToUnit}" )

    # convert the fromvalue to bytes
    case "${_fromUnit}" in
        k)
            _fromValue=$(( ${_fromValue} * 1024 ))
        ;;
        m)
            _fromValue=$(( ${_fromValue} * 1024 * 1024 ))
        ;;
        g)
            _fromValue=$(( ${_fromValue} * 1024 * 1024 * 1024 ))
        ;;
        t)
            _fromValue=$(( ${_fromValue} * 1024 * 1024 * 1024 * 1024 ))
        ;;
    esac
    # set the from unit to bytes in case we need it later
    _fromUnit="b"

    # now convert fromunit from bytes into the requested unit
    case "${_convertToUnit}" in
        b)
            echo "${_fromValue}"
        ;;
        k)
            echo $(( ${_fromValue} / 1024 ))
        ;;
        m)
            echo $(( ${_fromValue} / 1024 / 1024 ))
        ;;
        g)
            echo $(( ${_fromValue} / 1024 / 1024 / 1024 ))
        ;;
        t)
            echo $(( ${_fromValue} / 1024 / 1024 / 1024 /1024 ))
        ;;
        *)
            echo ""
            return ${E_ERROR}
        ;;
    esac

    return ${E_SUCCESS}
}
# validates that a given string is in the format <int><char>, eg 32G
function is_valid_size_unit() {
    local _string="${1}"
    local _validUnits="${2}"

    # if we werent given any valid units then set some
    if [[ -z "${_validUnits}" ]]; then
        # bytes, kilo, mega, giga, tera
        _validUnits="b,k,m,g,t"
    fi

    local _unit="${_string: -1}"
    local _value="${_string%?}"

    # check if the value is an int
    if ! is_int "${_value}"; then
        return ${E_ERROR}
    fi

    # check if the unit is valid
    IFS=","
    for unit in ${_validUnits}; do
        if [[ "$( str_to_lower "${unit}" )"  == "$(str_to_lower "${_unit}" )" ]]; then
            return ${E_SUCCESS}
        fi
    done

    # wasnt found so return an error
    return ${E_ERROR}
}
