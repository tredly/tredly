#!/usr/bin/env bash

# Checks that ipfw is installed
function check_for_ipfw() {
    if [[ $( kldstat | grep 'ipfw.ko$' | wc -l ) -eq 0 ]]; then
        exit_with_error "IPFW is not loaded!"
    fi
}

# Restarts IPFW
# Restarting is not ideal due to the flushing of rules - tcp sessions are disconnected
function ipfw_restart() {
    service ipfw restart

    return $?
}

# puts an open port directive into a IPFW file
function ipfw_open_port() {
    local _uuid="${1}"
    local _direction="${2}"
    local _protocol="${3}"
    local _interface="${4}"
    local _fromIP="${5}"
    local _toIP="${6}"
    local _ports=$(trim "${7}")
    local _options
    local _log

    if [[ -z "${_ports}" ]]; then
        return ${E_ERROR}
    fi

    if [[ "${_CONF_COMMON[firewallEnableLogging]}" == "yes" ]]; then
        _log="log"
    fi

    if [[ "${_protocol}" == "tcp" ]]; then
        _options="setup keep-state"
    elif [[ "${_protocol}" == "udp" ]]; then
        _options="keep-state"
    fi

    local _jailPreamble

    # if a uuid was received then update a jail, otherwise do the host
    if [[ -n ${_uuid} ]]; then
        _jailPreamble="jexec trd-${_uuid}"
    fi
    # live update the firewall
    eval ${_jailPreamble} ipfw -q add allow ${_log} ${_protocol} from ${_fromIP} to ${_toIP} ${_ports} ${_direction} via ${_interface} ${_options}

    return $?
}

# adds a string to an IPFW table
function ipfw_add_table_member() {
    local _uuid="${1}"
    local _tableNumber="${2}"
    local _ip="${3}"

    # if a uuid was received then update a jail, otherwise do the host
    if [[ -n ${_uuid} ]]; then
        _jailPreamble="jexec trd-${_uuid}"
    fi
    # live update the firewall
    eval ${_jailPreamble} ipfw -q table ${_tableNumber} add ${_ip}
}

# Creates/overwrites an ipfw table rule within a file and then runs that script
function ipfw_add_persistent_table_member() {
    local _uuid="${1}"
    local _tableNumber="${2}"
    local _ip="${3}"
    
    local _exitCode=0
    
    # if a uuid was received then update a jail, otherwise do the host
    if [[ -n ${_uuid} ]]; then
        _jailPreamble="jexec trd-${_uuid}"
    fi
    
    # empty the file
    echo "#!/usr/bin/env bash" > /usr/local/etc/ipfw.table.${_tableNumber}
    
    local _ip4
    IFS=","
    for _ip4 in ${_ip}; do
        # update the table file
        echo "ipfw table ${_tableNumber} add ${_ip4}" >> /usr/local/etc/ipfw.table.${_tableNumber}
        _exitCode=$(( ${_exitCode} & $? ))
    done
    
    # check if ipfw module is loaded
    if [[ $( kldstat | grep 'ipfw.ko$' | wc -l ) -ne 0 ]]; then
        # run the script
        sh /usr/local/etc/ipfw.table.${_tableNumber}
        _exitCode=$(( ${_exitCode} & $? ))
    fi

    return ${_exitCode}
}

# Deletes an IPFW table
function ipfw_delete_table() {
    local _uuid="${1}"
    local _tableNumber="${2}"

    # if a uuid was received then update a jail, otherwise do the host
    if [[ -n ${_uuid} ]]; then
        _jailPreamble="jexec trd-${_uuid}"
    fi
    # live update the firewall
    eval ${_jailPreamble} ipfw -q table ${_tableNumber} flush

    return $?
}

# Updates all containergroup members whenever one of the members of the group changes (create/destroy)
function ipfw_container_update_containergroup_members() {
    local _containerGroup="${1}"
    local _partitionName="${2}"

    # get a list of containers within this partition
    local _partitionContainers=$( zfs_get_all_containers "${_partitionName}" )

    local _dataset
    local _ip4
    local _containerGroupDatasets

    # loop over them, checking if they are a part of this group
    IFS=$'\n'
    for _dataset in ${_partitionContainers}; do
        # check if this is a member of the container group
        if [[ "${_containerGroup}" == $(zfs get -H -o value -r ${ZFS_PROP_ROOT}:containergroupname ${_dataset} ) ]]; then
            # is a group member, so add its dataset and ip to the list
            _containerGroupDatasets+=("${_dataset}")

            local _ip4=$(zfs get -H -o value -r ${ZFS_PROP_ROOT}:ip4_addr ${_dataset} )
            _containerGroupIPs+=($( extractFromIP4Addr "${_ip4}" "ip4" ))
        fi
    done

    # loop over the datasets, updating the firewall rules within those containers
    for _dataset in ${_containerGroupDatasets[@]}; do

        # extract the uuid
        local _uuid=$( echo "${_dataset}" | rev | cut -d/ -f 1 | rev )
        local _containerMount="${TREDLY_PARTITIONS_MOUNT}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${_uuid}"

        # remove all lines relating to members table
        ipfw_delete_table "${_uuid}" "1"

        # add in the new members data
        for _ip4 in ${_containerGroupIPs[@]}; do
            # loop over the ips and add the table members
            ipfw_add_table_member "${_uuid}" "1" "${_ip4}"
        done
    done
}

# Updates an individual container's table with the given partition whitelist
function ipfw_container_set_partition_whitelist() {
    local _uuid="${1}"
    local _partitionName="${2}"

    local _dataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${_uuid}"
    local _exitCode=0
    local _ip4

    # get the partition whitelist ips
    IFS=$'\n' local _whitelist=($( zfs_get_custom_array "${TREDLY_PARTITIONS_MOUNT}/${_partitionName}" "${ZFS_PROP_ROOT}.ptn_ip4whitelist" ))

    # remove all lines relating to partition whitelist table
    ipfw_delete_table "${_uuid}" "2"
    _exitCode=$(( ${_exitCode} & $? ))

    # add in the whitelist data
    for _ip4 in ${_whitelist[@]}; do
        # loop over the ips and add the table members
        ipfw_add_table_member "${_uuid}" "2" "${_ip4}"
        _exitCode=$(( ${_exitCode} & $? ))
    done

    return ${_exitCode}
}

# Updates all partition members whenever one of the members of the partition changes (create/destroy) or whitelist is modified
function ipfw_container_update_partition_members() {
    local _partitionName="${1}"

    # get a list of containers within this partition
    local _partitionContainers=$( zfs_get_all_containers "${_partitionName}" )

    local _dataset
    local _exitCode=0

    # get the partition whitelist ips
    IFS=$'\n' local _whitelist=($( zfs_get_custom_array "${TREDLY_PARTITIONS_MOUNT}/${_partitionName}" "${ZFS_PROP_ROOT}.ptn_ip4whitelist" ))

    # loop over the partition members
    IFS=$'\n'
    for _dataset in ${_partitionContainers}; do
        # extract the uuid
        local _uuid=$( echo "${_dataset}" | rev | cut -d/ -f 1 | rev )

        ipfw_container_set_partition_whitelist "${_uuid}" "${_partitionName}"
        _exitCode=$(( ${_exitCode} & $? ))
    done

    return ${_exitCode}
}
