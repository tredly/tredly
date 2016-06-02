#!/usr/bin/env bash

# Deprecated - PF support was removed in favour of IPFW for version 0.9.0

function check_for_pf() {
    if ! type_exists 'pfctl'; then
        exit_with_error "Packet Filter (PF) is not installed!";
    fi
}

function reload_pf() {
    pfctl -F all -f /etc/pf/pf.conf > /dev/null 2>&1
    return $?
}

function pf_reload_anchor() {
    local _anchorName="${1}"
    local _anchorFile="${2}"

    local _exitCode

    # sanity checks
    if [[ -z "${_anchorName}" ]] || [[ -z "${_anchorFile}" ]]; then
        return $E_ERROR
    fi

    # reload anchor and hide output
    /sbin/pfctl -a "${_anchorName}" -f "${_anchorFile}" > /dev/null 2>&1

    _exitCode=$?

    #if [[ ${_exitCode} -ne 0 ]]; then
        #e_error "Failed to reload firewall rule ${_anchorFile}"
    #else
        #e_verbose "Reloaded anchor ${_anchorFile}"
    #fi
    return ${_exitCode}
}

function pf_flush_anchor() {
    local _anchorName="${1}"

    # sanity checks
    if [[ -z "${_anchorName}" ]]; then
        return $E_ERROR
    fi

    _exitCode=$?

    # flush anchor and hide output
    /sbin/pfctl -a "${_anchorName}" -F rules > /dev/null 2>&1

    if [[ ${_exitCode} -ne 0 ]]; then
        e_error "Failed to flush firewall rule ${_anchorName}"
    else
        e_verbose "Flushed firewall rule ${_anchorName}"
    fi

    return ${_exitCode}
}

# adds a table to the PF anchor
function add_pf_table() {
    local anchorName="${1}"
    local ip="${2}"
    local tableName="${3}"
    local anchorFile="${ANCHOR_DIR}/${anchorName}"
    local declaration="table <${tableName}> {"

    ## Set some table data in the file, checking if the table exists before adding it
    local tableExists=$(cat "${anchorFile}" | grep "${declaration}" | wc -l)

    if [[ "${tableExists}" -eq "0" ]]; then

        # doesn't exist yet so add it in with the ip address
        #add_data_to_start_of_file "${declaration}\n    ${ip}\n}" "${anchorFile}"
        echo -e "${declaration}\n    ${ip}\n}" >> "${anchorFile}"

    else
        # declaration exists, so try update it

        # first get the data between the two strings
        local anchorFileData="$(cat "${anchorFile}")"
        local dataBetween="$(get_data_between_strings "${declaration}" "}" "${anchorFileData}")"

        local searchedDataBetween="$(echo "${dataBetween}" | grep "${ip}[,]*")"

        # check if the ip exists between those strings
        if [[ -z "${searchedDataBetween}" ]]; then

            # not found so add it in
            $(add_line_to_file_after_string "    ${ip}, \\" "${declaration}" "${anchorFile}")
        fi
    fi
}

# Creates a firewall anchor file for a project and links it to the projects anchor
function create_anchor_file() {
    local anchorFile="${1}"
    local anchorName="${2}"
    local mainAnchorFile="${3}"
    local rdrAnchor="${4}"

    if [[ -z "${rdrAnchor}" ]]; then
        rdrAnchor="false"
    fi

    ## Check if the file exists, and if it doesn't then create it with appropriate permissions
    if [[ ! -f "${anchorFile}" ]]; then
        touch "${anchorFile}"
        chmod 600 "${anchorFile}"
    fi

    # only include it if we were given a file to include it into
    if [[ -n "${mainAnchorFile}" ]]; then
        pf_include_anchor "${mainAnchorFile}" "${anchorName}" "${anchorFile}" "${rdrAnchor}"
    fi
}

# includes a given anchor file into another anchor file
function pf_include_anchor() {
    local _anchorFile="${1}"
    local _anchorNameToInclude="${2}"
    local _anchorFileToInclude="${3}"
    local _isRdrAnchor="${4}"

    local _anchorDefinition="anchor ${_anchorNameToInclude}"

    # check to see if there are definitions in the main anchor file
    if [[ $(cat "${_anchorFile}" | grep "^${_anchorDefinition}$" | wc -l) -eq 0 ]]; then
        local _anchorDefinition
        if [[ "${_isRdrAnchor}" == "true" ]]; then
            _anchorDefinition="rdr-${_anchorDefinition}"
        else
            _anchorDefinition="anchor ${anchorName}"
        fi

        # doesnt exist so add it in
        {
            echo "${_anchorDefinition}"
            echo "load anchor ${_anchorNameToInclude} from \"${_anchorFileToInclude}\""
        } >> "${_anchorFile}"

        return $E_SUCCESS
    else
        e_verbose "Anchor definition ${_anchorDefinition} already exists"

        return $E_ERROR
    fi
}

# Open port forwards using PF
function open_proxy_port() {
    local anchorFile="${1}"
    local protocol="${2}"
    local interface="${3}"
    local sourceIP4="${4}"
    local destIP4="${5}"
    local hostPort="${6}"
    local containerIP4="${7}"
    local containerPort="${8}"

    local logging=""
    if [ -n "${9}" ] && [ "${9}" = "yes" ]; then
        logging="log"
    fi

    # do some error checking
    # if ports == empty string then don't do anything
    if [[ -z "${hostPort}" || -z "${containerPort}" ]]; then
        e_verbose "No ${protocol} ports specified, skipping layer 4 proxy port"
        return $E_ERROR
    fi

    # create the base rule
    local forwardRule="rdr pass ${logging} on ${interface} proto ${protocol} from {${sourceIP4}} to ${destIP4} port ${hostPort} -> ${containerIP4} port ${containerPort}"

    # check that this interface + port isn't already forwarded - cant forward the same port twice!
    local portExists=$(cat "${anchorFile}" | grep -F "${destIP4} port ${hostPort} ->" | wc -l)
    if [[ "${portExists}" -ne "0" ]]; then
        e_error "Cannot add layer 4 proxy, port already exists: ${forwardRule}"
        return $E_ERROR
    fi

    # check to see if this exists in the file already
    local ruleExists=$(cat "${PROXY_ANCHOR_FILE}" | grep -F "${forwardRule}" | wc -l)
    if [[ "${ruleExists}" -eq "0" ]]; then
        e_verbose "Adding layer 4 proxy rule: ${forwardRule}"
        # add the rules
        add_data_to_start_of_file "${forwardRule}" "${anchorFile}"

        return $E_SUCCESS
    else
        e_verbose "Layer 4 proxy rule already exists"
        return $E_ERROR
    fi
}

# Open ports using PF
function open_fw_ports() {
    local anchorName="${1}"
    local direction="${2}"
    local protocol="${3}"
    local interface="${4}"
    local otherHosts="${5}"
    local ip="${6}"
    local ports=$(trim "${7}")
    local extras

    local logging=""
    if [ -n "${8}" ] && [ "${8}" = "yes" ]; then
        logging="log"
    fi

    if [[ -n "${9}" ]]; then
        extras="${9}"
    fi

    # do some error checking
    # if ports == empty string then don't do anything
    if [[ -z "${ports}" ]]; then
        e_verbose "No ${protocol} ports specified, skipping open firewall ports"
        return $E_ERROR
    fi

    # first create the directory in case it doesnt exist
    mkdir -p "${ANCHOR_DIR}"

    ## Form a full path to the anchorfile
    local anchorFile="${ANCHOR_DIR}/${anchorName}"

    # create the base rule
    local currentRule=""
    currentRule="pass ${direction} ${logging} quick on ${interface} inet proto ${protocol} from {${ip}} to {${otherHosts}}"

    # Check if a port was included and include it in the rule if so
    if [[ -n "${ports}" && "${ports}" != "any" ]]; then
        currentRule="${currentRule} port {${ports}}"
    fi

    # now add in the extras
    currentRule="${currentRule} ${extras}"

    # check to see if this exists in the file already
    local ruleExists=$(cat "${anchorFile}" | grep "^${currentRule}$" | wc -l)

    if [[ "${ruleExists}" -eq "0" ]]; then
        e_verbose "Adding firewall rule: ${currentRule}"
        eval 'echo "${currentRule}" >> "${anchorFile}"'
    else
        e_verbose "Firewall rule already exists: ${currentRule}"
    fi
}

## Inspects the pf.conf rules, removing any that relate to
## the container with given IP address
## Arguments:
##     1. String. Container IP address
##     2. String. Anchor/project UUID
##
## Usage:
##     remove_fw_rules 12.23.45.67 111-11111111-1111211
##
## Return:
##     void
function remove_fw_rules() {
    local ip="${1}"
    local anchorName="${2}"

    local anchorFile="${ANCHOR_DIR}/${anchorName}"
    local projectsAnchorFile="${PROJECTS_ANCHOR_FILE}"

    local regex=$(regex_escape "${ip}")

    # sanity check
    if ! is_valid_ip4 "${ip}"; then
        e_error "${ip} is not a valid ip4 address"
        return $E_ERROR;
    fi

    # remove the lines from the project anchor file
    if remove_lines_from_file "${anchorFile}" "${ip}" false; then
        e_verbose "Removed firewall rules"
        # get the data between the members declaration. if its empty then delete the rest of the file
        local membersFileData=$(cat "${anchorFile}" )
        local membersData=$(get_data_between_strings "table <members> {" "}" "${membersFileData}")
        local strippedMembersData=$(strip_whitespace "${membersData}")
        local numMembers=$( echo -n "${membersData}" | wc -l )

        # if it has members data then do members things
        local _hasMembers=$( cat "${anchorFile}" | grep -F "table <members> {" | wc -l )
        if [[ ${_hasMembers} -gt 0 ]]; then
            # if it is empty then delete the file - no members means no project
            if [[ -z "${strippedMembersData}" ]]; then
                rm -f "${anchorFile}"
            else
                # fix the edge case of the last member being removed,
                # and the new last member remaining in the form: "10.0.0.1, \"
                # which causes pf to fail

                membersData=$( echo -e "${membersData}" | sed '/./,$!d' ) # remove the starting newline
                membersData=$( ltrim "${membersData}" ) # and whitespace at the start
                membersData=$( echo -en "${membersData}" )   # remove the trailing newline
                membersData=$( remove_string_from_end_of_string ', \' "${membersData}" )

                # remove the declaration
                $( delete_data_from_file_between_strings_inclusive 'table <members> {' '}' "${anchorFile}" )

                # and re-add it
                $( add_pf_table "${anchorName}" "${membersData}" "members" )
            fi
        fi

        # check to see if this file has no members and if so, delete it
        if [[ -z ${membersFileData} ]]; then
            e_verbose "Deleting anchor file ${anchorFile}"
            rm -f "${anchorFile}"
        fi
    else
        e_error "Failed to remove firewall rules"
    fi

    # check to see if the project file was removed, if so then remove the reference in projects anchor file
    if [[ ! -e "${anchorFile}" ]]; then
        # remove the lines from the main projects anchor file
        if remove_lines_from_file "${projectsAnchorFile}" "anchor ${anchorName}"; then
            e_verbose "Removed project ${anchorName} from ${projectsAnchorFile}"
        else
            e_error "Failed to remove project ${anchorName} from ${projectsAnchorFile}"
        fi
    fi

    return $E_SUCCESS;
}

function remove_l4_proxy_rules() {
    local ip="${1}"
    local anchorName="${2}"

    local anchorFile="${PROXY_DIR}/${anchorName}"

    local regex=$(regex_escape "${ip}")

    # sanity check
    if ! is_valid_ip4 "${ip}"; then
        e_error "${ip} is not a valid ip4 address"
        return $E_ERROR;
    fi

    # remove the lines from the rdr anchor file
    if remove_lines_from_file "${anchorFile}" "${ip}" false; then
        e_verbose "Removed layer 4 proxy rules"

        # check to see if this file is empty and if so, delete it
        local _anchorContent=$(cat "${anchorFile}" )
        if [[ -z ${_anchorContent} ]]; then
            e_verbose "Deleting rdr anchor file ${anchorFile}"
            rm -f "${anchorFile}"
        fi
    else
        e_error "Failed to remove firewall rules"
    fi

    # check to see if the rdr anchor file was removed, if so then remove the reference in rdr anchor file
    if [[ ! -e "${anchorFile}" ]]; then
        # remove the lines from the main projects anchor file
        if remove_lines_from_file "${PROXY_ANCHOR_FILE}" "anchor ${anchorName}"; then
            e_verbose "Removed project ${anchorName} from ${PROXY_ANCHOR_FILE}"
        else
            e_error "Failed to remove project ${anchorName} from ${PROXY_ANCHOR_FILE}"
        fi
    fi

    return $E_SUCCESS;
}

# Creates a standalone table file
function pf_create_table_file() {
    local tableFile="${1}"
    local tableName="${2}"
    local -a tableMembers=("${!3}")

    # create the table dir if it doesnt exist
    if [[ ! -d "${TABLE_DIR}" ]]; then
        mkdir -p "${TABLE_DIR}"
    fi

    ## Check if the file exists, and if it doesn't then create it with appropriate permissions
    if [[ ! -f "${tableFile}" ]]; then
        touch "${tableFile}"
        chmod 600 "${tableFile}"
    fi

    local memberDeclaration

    # add the members in if we were given some
    if [[ ${#tableMembers[@]} -gt 0 ]]; then
        # add the members into the file
        {
            for member in ${tableMembers[@]}; do
                # validate the ip4 before echoing it out
                if is_valid_ip4 "${member}"; then
                    echo "${member}"
                fi
            done
        } > "${tableFile}"
    fi

    return $E_SUCCESS
}

# includes a given table into an anchor
function pf_include_table() {
    local _tableFile="${1}"
    local _tableName="${2}"
    local _anchorFile="${3}"

    # make sure both files exist
    if [[ ! -f "${_tableFile}" ]]; then
        return $E_ERROR
    fi
    if [[ ! -f "${_anchorFile}" ]]; then
        return $E_ERROR
    fi
    # and that a table name was given
    if [[ -z "${_tableName}" ]]; then
        return $E_ERROR
    fi

    # create the declaration
    local _declaration="table <${_tableName}> file \"${_tableFile}\""

    $( add_data_to_start_of_file_if_not_exists "${_declaration}" "${_anchorFile}" )

    return $?
}

# removes an include of a table within an anchor
function pf_remove_include_table() {
    local _tableName="${1}"
    local _anchorFile="${2}"

    # remove the lines from the file
    if remove_lines_from_file "${_anchorFile}" "<${_tableName}>" "false"; then
        return $E_SUCCESS
    fi

    return $E_ERROR
}
