#!/usr/bin/env bash

# Checks whether unbound is installed on the host or not
function check_for_unbound() {
    if ! type_exists 'unbound'; then
        exit_with_error "Unbound is not installed!";
    fi
}

# reloads unbound
function unbound_reload() {
    service unbound reload 2> /dev/null
    return $?
}
# restarts unbound
function unbound_restart() {
    service unbound restart 2> /dev/null
    return $?
}

# inserts a record into a given unbound config
# args:
# _hostname - the hostname to insert
# _ip4 - the ip4 to associate with this record
# _identifier - the ip address or other identifier of the record. Used so that specific records can be removed without affecting others.
# for example, using tredly replace would cause all records to be removed without deleting by this identifier, as the new container is
# created first, then destroyed. A destruction on hostname alone would cause all records to be removed.
function unbound_insert_a_record() {
    local _hostname="${1}"
    local _ip4="${2}"
    local _identifier="${3}"
    local _filename

    # validate input
    if [[ -z "${_hostname}" ]]; then
        return $E_ERROR
    fi
    if [[ -z "${_ip4}" ]]; then
        return $E_ERROR
    fi
    if ! is_valid_ip4 "${_ip4}"; then
        return $E_ERROR
    fi

    # base the filename off the last 3 (sub)domains
    _filename=$( echo "${_hostname}" | rev | cut -d. -f 3 -f 2 -f 1 | rev )

    # substitute dots for underscores
    _filename="${_filename//./_}"

    # set up the data to insert so that we can check if it already exists
    local _data="local-data: \"${_hostname} IN A ${_ip4}\""
    # add the identifier as a comment if it was received
    if [[ -n "${_identifier}" ]]; then
        _data="${_data} # ${_identifier}"
    fi

    local numLines=0
    # check if file exists and get its contents
    if [[ -f "${UNBOUND_CONFIG_DIR}/${_filename}" ]]; then
        local _grepData=$( str_replace "${_data}" '"' '\"' )

        numLines=$(cat "${UNBOUND_CONFIG_DIR}/${_filename}" | grep "${_grepData}" | wc -l)
    fi

    # add it if it doesnt exist
    if [[ ${numLines} -eq 0 ]]; then
        echo "${_data}" >> "${UNBOUND_CONFIG_DIR}/${_filename}"
    fi

    return $E_SUCCESS
}

# inserts a record into a given unbound config
# hostname is necessary to work out what file the record resides in
# identifier is the uuid of the container to delete - as a comment at the end of the line to be deleted.
# eg: local-data: "www.vuid.com IN A 10.0.255.254" # <uuid>
# Where: 10.0.0.3 is the identifer
function unbound_remove_records() {
    local _hostname="${1}"
    local _identifier="${2}"
    local _filename

    # validate input
    if [[ -z "${_hostname}" ]]; then
        return $E_ERROR
    fi

    # base the filename off the last 3 (sub)domains
    _filename=$( echo "${_hostname}" | rev | cut -d. -f 3 -f 2 -f 1 | rev )

    # substitute dots for underscores
    _filename="${_filename//./_}"

    _returnCode=0

    # remove any by comment any references to this ip address
    remove_lines_from_file "${UNBOUND_CONFIG_DIR}/${_filename}" "# ${_identifier}$" "true"
    _returnCode=$(( _returnCode & $? ))

    return ${_returnCode}
}
