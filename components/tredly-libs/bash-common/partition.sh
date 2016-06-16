#!/usr/bin/env bash

# creates a partition on the host
# args - partitionname
function partition_create() {
    local _partitionName="${1}"
    local _partitionHDD="${2}"
    local _partitionCPU="${3}"
    local _partitionRAM="${4}"
    local _silent="${5}"

    local _exitCode

    #####
    # Pre flight checks

    # make sure we received a partition name
    if [[ -z "${_partitionName}" ]]; then
        exit_with_error "Please include a name for your partition."
    fi

    # ensure that this partition doesnt already exist
    if [[ $( zfs list "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}" 2> /dev/null | wc -l ) -ne 0 ]]; then
        exit_with_error "Partition \"${_partitionName}\" already exists"
    fi

    # ensure received units are correct
    if [[ -n "${_partitionHDD}" ]]; then
        if ! is_valid_size_unit "${_partitionHDD}" "m,g"; then
            exit_with_error "Invalid HDD specification: ${_partitionHDD}. Please use the format HDD=<size><unit>, eg HDD=1G."
        fi
    fi
    if [[ -n "${_partitionCPU}" ]]; then
        if ! is_int "${_partitionCPU}"; then
            exit_with_error "Invalid CPU specification: ${_partitionCPU}. Please use the format CPU=<int>, eg CPU=1"
        fi
    fi
    if [[ -n "${_partitionRAM}" ]]; then
        if ! is_valid_size_unit "${_partitionRAM}" "m,g"; then
            exit_with_error "Invalid RAM specification: ${_partitionRAM}. Please use the format RAM=<size><unit>, eg RAM=1G."
        fi
    fi

    # End pre flight checks

    if [[ "${_silent}" != "true" ]]; then
        e_header "Creating partition \"${_partitionName}\""

        e_note "Creating ZFS dataset"
    fi
    
    _exitCode=0
    
    # create the partition
    zfs_create_dataset "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}" "${TREDLY_PARTITIONS_MOUNT}/${_partitionName}"
    _exitCode=$(( ${_exitCode} & $? ))
    
    # and the containers dataset
    zfs_create_dataset "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}" "${TREDLY_PARTITIONS_MOUNT}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}"
    _exitCode=$(( ${_exitCode} & $? ))
    
    # and the data dataset
    zfs_create_dataset "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_PTN_DATA_DIR_NAME}" "${TREDLY_PARTITIONS_MOUNT}/${_partitionName}/${TREDLY_PTN_DATA_DIR_NAME}"
    _exitCode=$(( ${_exitCode} & $? ))
    
    # and the remote containers dataset
    zfs_create_dataset "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_PTN_REMOTECONTAINERS_DIR_NAME}" "${TREDLY_PARTITIONS_MOUNT}/${_partitionName}/${TREDLY_PTN_REMOTECONTAINERS_DIR_NAME}"
    _exitCode=$(( ${_exitCode} & $? ))
    
    # and the persistent storage dataset
    zfs_create_dataset "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_PERSISTENT_STORAGE_DIR_NAME}" "${TREDLY_PARTITIONS_MOUNT}/${_partitionName}/${TREDLY_PERSISTENT_STORAGE_DIR_NAME}"
    _exitCode=$(( ${_exitCode} & $? ))
    
    # create some default directories within the data dataset
    mkdir -p "${TREDLY_PARTITIONS_MOUNT}/${_partitionName}/${TREDLY_PTN_DATA_DIR_NAME}/credentials"
    mkdir -p "${TREDLY_PARTITIONS_MOUNT}/${_partitionName}/${TREDLY_PTN_DATA_DIR_NAME}/scripts"
    mkdir -p "${TREDLY_PARTITIONS_MOUNT}/${_partitionName}/${TREDLY_PTN_DATA_DIR_NAME}/sslCerts"

    if [[ "${_silent}" != "true" ]]; then
        if [[ ${_exitCode} -eq 0 ]]; then
            e_success "Success"
        else
            exit_with_error "Failed"
        fi
    fi

    # set the partition name
    zfs_set_property "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}" "${ZFS_PROP_ROOT}:partitionname" "${_partitionName}"

    # apply HDD restrictions
    if [[ -n "${_partitionHDD}" ]]; then
        if [[ "${_silent}" != "true" ]]; then
            e_note "Applying HDD value ${_partitionHDD}"
        fi

        zfs_set_property "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}" "quota" "${_partitionHDD}"

        if [[ "${_silent}" != "true" ]]; then
            if [[ $? -eq 0 ]]; then
                e_success "Success"
            else
                e_error "Failed"
            fi
        fi
    fi

    # apply CPU restrictions
    if [[ -n "${_partitionCPU}" ]]; then
        if [[ "${_silent}" != "true" ]]; then
            e_note "Applying CPU value ${_partitionCPU}"
        fi

        zfs_set_property "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}" "${ZFS_PROP_ROOT}:maxcpu" "${_partitionCPU}"
        _exitCode=$?

        if [[ "${_silent}" != "true" ]]; then
            if [[ ${_exitCode} -eq 0 ]]; then
                e_success "Success"
            else
                e_error "Failed"
            fi
        fi
    fi

    # apply RAM restrictions
    if [[ -n "${_partitionRAM}" ]]; then
        if [[ "${_silent}" != "true" ]]; then
            e_note "Applying RAM value ${_partitionRAM}"
        fi

        zfs_set_property "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}" "${ZFS_PROP_ROOT}:maxram" "${_partitionRAM}"
        _exitCode=$?

        if [[ "${_silent}" != "true" ]]; then
            if [[ ${_exitCode} -eq 0 ]]; then
                e_success "Success"
            else
                e_error "Failed"
            fi
        fi
    fi

}

# Modifies partition parameters
function partition_modify() {
    local _partitionName="${1}"
    local _newPartitionName="${2}"
    local _newPartitionHDD="${3}"
    local _newPartitionCPU="${4}"
    local _newPartitionRAM="${5}"
    local _newIp4Whitelist="${6}"

    local _exitCode

    #####
    # Pre flight checks

    # make sure we received a partition name
    if [[ -z "${_partitionName}" ]]; then
        exit_with_error "Please include the name of the partition to modify."
    fi

    # ensure that the old partition name exists
    if [[ $( zfs list "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}" 2> /dev/null | wc -l ) -eq 0 ]]; then
        exit_with_error "No Partition named \"${_partitionName}\" found."
    fi

    # ensure that this new partition name doesnt already exist
    if [[ $( zfs list "${ZFS_TREDLY_PARTITIONS_DATASET}/${_newPartitionName}" 2> /dev/null | wc -l ) -ne 0 ]]; then
        exit_with_error "Partition \"${_newPartitionName}\" already exists"
    fi

    # check for running containers within the partition to be moved
    if [[ -n "${_newPartitionName}" ]]; then
        # check if there are built containers
        local _containerCount=$( zfs_get_all_containers "${_partitionName}" | wc -l )

        if [[ ${_containerCount} -gt 0 ]]; then
            exit_with_error "Partition ${_partitionName} currently has built containers. Please destroy them and run this command again."
        fi
    fi

    # ensure received units are correct
    if [[ -n "${_newPartitionHDD}" ]]; then
        if ! is_valid_size_unit "${_newPartitionHDD}" "m,g"; then
            exit_with_error "Invalid HDD specification: ${_newPartitionHDD}. Please use the format HDD=<size><unit>, eg HDD=1G."
        fi
    fi
    if [[ -n "${_newPartitionCPU}" ]]; then
        if ! is_int "${_newPartitionCPU}"; then
            exit_with_error "Invalid CPU specification: ${_newPartitionCPU}. Please use the format CPU=<int>, eg CPU=1"
        fi
    fi
    if [[ -n "${_newPartitionRAM}" ]]; then
        if ! is_valid_size_unit "${_newPartitionRAM}" "m,g"; then
            exit_with_error "Invalid RAM specification: ${_newPartitionRAM}. Please use the format RAM=<size><unit>, eg RAM=1G."
        fi
    fi

    # End pre flight checks

    e_header "Modifying existing partition \"${_partitionName}\""

    if [[ -n "${_newPartitionName}" ]]; then
        e_note "Renaming ZFS dataset"

        local _oldDataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}"
        local _newDataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_newPartitionName}"

        _exitCode=0
        # rename the partition
        zfs rename "${_oldDataset}" "${_newDataset}"
        _exitCode=$(( ${_exitCode} & $? ))

        # change it's own and it's children's mount points
        # get a list of itself and children
        local _lines=$( zfs get -H -o name,value -r mountpoint ${_newDataset} 2> /dev/null | sort -r -n )

        local _line _dataset _oldMountpoint _newMountpoint
        local _prefix="${TREDLY_PARTITIONS_MOUNT}/${_partitionName}"
        IFS=$'\n'

        for _line in ${_lines}; do
            # split the line into dataset and mountpoint
            _dataset=$( echo "${_line}" | awk '{ print $1 }' )
            _oldMountpoint=$( echo "${_line}" | awk '{ print $2 }' )

            # force unmount the dataset
            zfs umount -f "${_dataset}" 2> /dev/null
            _exitCode=$(( ${_exitCode} & $? ))

            # sub in the new partition name for new mountpoint
            _newMountpoint="${TREDLY_PARTITIONS_MOUNT}/${_newPartitionName}$( rcut "${_oldMountpoint}" "${_prefix}" )"

            # apply new mountpoint
            zfs_set_property "${_dataset}" "mountpoint" "${_newMountpoint}"
            _exitCode=$(( ${_exitCode} & $? ))

            # remount the dataset
            zfs mount "${_dataset}"
            _exitCode=$(( ${_exitCode} & $? ))
        done

        if [[ ${_exitCode} -eq 0 ]]; then
            e_success "Success"
        else
            exit_with_error "Failed"
        fi

        # set the partition name
        zfs_set_property "${_newDataset}" "${ZFS_PROP_ROOT}:partitionname" "${_newPartitionName}"

        # set the new partition name as the one to modify for the stuff below
        _partitionName="${_newPartitionName}"
    fi

    # apply HDD restrictions
    if [[ -n "${_newPartitionHDD}" ]]; then
        e_note "Applying HDD value ${_newPartitionHDD}"

        local _partitionDataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}"

        zfs_set_property "${_newDataset}" "quota" "${_partitionDataset}"

        if [[ $? -eq 0 ]]; then
            e_success "Success"
        else
            e_error "Failed"
        fi
    fi

    # apply CPU restrictions
    if [[ -n "${_newPartitionCPU}" ]]; then
        e_note "Applying CPU value ${_newPartitionCPU}"

        local _partitionDataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}"

        zfs_set_property "${_partitionDataset}" "${ZFS_PROP_ROOT}:maxcpu" "${_newPartitionCPU}"
        _exitCode=$?

        if [[ ${_exitCode} -eq 0 ]]; then
            e_success "Success"
        else
            e_error "Failed"
        fi
    fi

    # apply RAM restrictions
    if [[ -n "${_newPartitionRAM}" ]]; then
        e_note "Applying RAM value ${_newPartitionRAM}"

        local _partitionDataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}"

        zfs_set_property "${_partitionDataset}" "${ZFS_PROP_ROOT}:maxram" "${_newPartitionRAM}"
        _exitCode=$?

        if [[ ${_exitCode} -eq 0 ]]; then
            e_success "Success"
        else
            e_error "Failed"
        fi
    fi

    # apply ip4 whitelisting
    if [[ -n "${_newIp4Whitelist}" ]]; then
        local _partitionDataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}"

        # check if it was a clear command
        if [[ "${_newIp4Whitelist}" == "clear" ]]; then
            e_note "Clearing whitelist."
            if partition_ipv4whitelist_clear "${_partitionName}"; then
                e_success "Success"

            else
                e_error "Failed"
            fi
        else
            e_note "Applying whitelist."
            # convert the whitelist into an array to pass
            local -a _whitelistArray
            IFS=',' read -ra _whitelistArray <<< "${_newIp4Whitelist}"

            # Set the whitelist
            if partition_ipv4whitelist_create _whitelistArray[@] "${_partitionName}"; then
                # apply whitelist to partition members
                if ipfw_container_update_partition_members "${_partitionName}"; then
                    e_success "Success"
                else
                    e_error "Failed"
                fi
            else
                e_error "Failed"
            fi
        fi
    fi
}

# destroys a partition
# args - partitionname
function partition_destroy() {
    local _partitionName="${1}"
    local _userPrompt="${2}"
    local _confirm

    # make sure we received a partition name
    if [[ -z "${_partitionName}" ]]; then
        exit_with_error "Please include a partition name."
    fi

    # check if the partition exists
    if [[ -z "$( zfs list "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}" 2> /dev/null )" ]]; then
        exit_with_error "Partition ${_partitionName} does not exist."
    fi

    e_header "Destroying partition \"${_partitionName}\""

    if [[ "${_userPrompt}" != "false" ]]; then
        # confirm with the user that they want to destroy the partition, containers and all
        echo "Everything within this partition will be destroyed. This includes partition data."
        read -p "Are you sure you wish to destroy this partition? (y/n) " _confirm

        if [ "${_confirm}" != "y" ] && [ "${_confirm}" != "Y" ]; then
            exit ${E_ERROR}
        fi
    fi

    partition_destroy_containers "${_partitionName}" "true"

    # now destroy the dataset
    zfs destroy -rf "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}"

    # remove the dir
    #rmdir "${TREDLY_PARTITIONS_MOUNT}/${_partitionName}" 2> /dev/null

    if [[ $? -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi
}

# Destroys ALL partitions
function partition_destroy_all() {
    _pNames=$( get_partition_names )

    e_header "Destroying ALL partitions"

    e_note "The following partitions will be destroyed:"
    IFS=$'\n'
    for _pName in ${_pNames}; do
        echo "  ${_pName}"
    done

    # confirm with the user that they want to destroy the partition, containers and all
    echo "All data within these partitions will be destroyed."
    read -p "Are you sure you wish to destroy these partitions? (y/n) " _confirm

    if [ "${_confirm}" != "y" ] && [ "${_confirm}" != "Y" ]; then
        exit ${E_ERROR}
    fi

    IFS=$'\n'
    for _pName in ${_pNames}; do
        partition_destroy "${_pName}" "false"
    done
}

# destroys containers within partition
function partition_destroy_containers() {
    local _partitionName="${1}"
    local _force="${2}"

    if [[ -z "${_partitionName}" ]]; then
        exit_with_error "Please include a partition name."
    fi

    # check if there are any containers on this partition
    local _containerList=$( zfs_get_all_containers "${_partitionName}" )

    local _uuidsNames

    # loop over each dataset, getting its containername
    if [[ -n ${_containerList} ]]; then
        IFS=$'\n'
        local _dataset _name _uuid _uuidName
        for _dataset in ${_containerList}; do
            # extract the UUID from the dataset as the uuid in zfs may not be set
            _uuid=$( echo "${_dataset}" | rev | cut -d/ -f 1 | rev )
            
            _name=$( zfs_get_property "${_dataset}" "${ZFS_PROP_ROOT}:containername" )

            _uuidsNames=$( echo -e "${_uuidsNames}\n${_uuid}^${_name}")
        done

        # sort them into alphabetical order
        _uuidsNames=$( echo "${_uuidsNames}" | sort -t '^' -k 2)

        if [[ "${_force}" != "true" ]]; then
            e_note "Partition ${_partitionName} currently contains the following containers:"

            # echo them out
            for _uuidName in ${_uuidsNames}; do
                _name=$( echo "${_uuidName}" | cut -d'^' -f 2 )
                echo "  ${_name}"
            done

            e_note "These containers will be destroyed."
            # confirm with the user that they want to destroy the partition, containers and all
            read -p "Are you sure you wish to destroy these containers? (y/n) " _confirm

            if [ "${_confirm}" != "y" ] && [ "${_confirm}" != "Y" ]; then
                exit ${E_ERROR}
            fi
        fi

        # continue on with destroying the containers
        IFS=$'\n'
        for _uuidName in ${_uuidsNames}; do
            _uuid=$( echo "${_uuidName}" | cut -d'^' -f 1 )

            tredly-build destroy container "${_uuid}"
        done
    else
        e_note "Partition ${_partitionName} has no containers."
    fi
}

# takes a uuid, and returns the partition it was found in
function get_container_partition() {
    local _uuid="${1}"

    local _containerDataset=$( zfs list -d6 -rH -o name | grep -E "${TREDLY_CONTAINER_DIR_NAME}/${_uuid}$" )

    # remove the left hand side
    _containerDataset=$(rcut "${_containerDataset}" "${TREDLY_PARTITIONS_MOUNT}/" )
    # remove the right hand side
    _containerDataset=$(lcut "${_containerDataset}" "/${TREDLY_CONTAINER_DIR_NAME}/${_uuid}" )

    echo "${_containerDataset}"

}

# lists out all partition names
function get_partition_names() {
    local _partitionDatasets=$( zfs list -d1 -rH -o name ${ZFS_TREDLY_PARTITIONS_DATASET}  | grep -Ev "^${ZFS_TREDLY_PARTITIONS_DATASET}$" )

    IFS=$'\n'
    local _dataset
    for _dataset in ${_partitionDatasets}; do
        # extract the last part of the dataset
        echo "${_dataset}" | rev | cut -d'/' -f 1 | rev
    done
}

# lists out partition details
function partition_list() {
    local _partitionName="${1}"
    local -a _datasets
    local _dataset
    local _quota _usedSpace _maxCPU _maxRAM _numContainers

    # if partition name received then list that only,
    # if no partition name was received then list all of them
    if [[ -n "${_partitionName}" ]]; then
        # make sure this dataset exists
        local _partitionExists=$( zfs list -H ${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName} | wc -l )

        if [[ ${_partitionExists} -eq 1 ]]; then
            _datasets+=("${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}")
        fi
    else
        local _partitionNames=$( get_partition_names )

        # add the datasets to the list
        IFS=$'\n'
        for _partitionName in ${_partitionNames}; do
            _datasets+=("${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}")
        done
    fi

    if [[ ${#_datasets[@]} -eq 0 ]]; then
        exit_with_error "No datasets found"
    fi

    local _listString=''

    # loop over the datasets
    for _dataset in ${_datasets[@]}; do
        # get the data
        _partitionName=$( zfs_get_property "${_dataset}" "${ZFS_PROP_ROOT}:partitionname" )
        _usedSpace=$( zfs_get_property "${_dataset}" "used" )
        _quota=$( zfs_get_property "${_dataset}" "quota" )
        _maxCPU=$( zfs_get_property "${_dataset}" "${ZFS_PROP_ROOT}:maxcpu" )
        _maxRAM=$( zfs_get_property "${_dataset}" "${ZFS_PROP_ROOT}:maxram" )

        # clean up some default values
        if [[ "${_quota}" == "none" ]]; then
            _quota="~"
        fi
        if [[ "${_maxCPU}" == "-" ]]; then
            _maxCPU='~'
        fi
        if [[ "${_maxRAM}" == "-" ]]; then
            _maxRAM='~'
        fi

        _numContainers=$( zfs list -d3 -rH -o name "${_dataset}/${TREDLY_CONTAINER_DIR_NAME}" | grep -Ev "${TREDLY_CONTAINER_DIR_NAME}\$|${_partitionName}\$" | wc -l )

        _listString=$( echo "${_listString}" ; printf "%s^%s^%s^%s^%s^%s\n" \
                                               "${_partitionName}" "${_maxCPU}" "${_maxRAM}" "${_usedSpace}/${_quota}" "-" "${_numContainers}")
    done

    if [[ ${#_datasets[@]} -eq 0 ]]; then
        e_note "No partitions found"
    else
        e_header "Listing All Partitions"
        echo -e "--------------------"
        printf "\e[1m"
        echo -e "Partition^CPU^RAM^HDD(Used/Total)^PublicIPs^Containers\e[0m\e[39m\n${_listString}" | column -ts^
        echo -e "--------------------\n`ltrim "${#_datasets[@]}"` partitions listed."
    fi
}

# returns whether or not the partition exists
function partition_exists() {
    local _partitionName="${1}"

    # check if the partition exists
    if [[ -z "$( zfs list "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}" 2> /dev/null )" ]]; then
        return ${E_ERROR}
    fi

    return ${E_SUCCESS}
}

# Creates an ipv4 whitelist for a partition
function partition_ipv4whitelist_create() {
    local -a _ip4whitelist=("${!1}")
    local _partitionName="${2}"
    local -a _ip4whitelistValidated

    # add in any whitelisting from the command line
    if [[ ${#_ip4whitelist[@]} -eq 0 ]]; then
        return ${E_ERROR}
    fi

    if [[ -z "${_partitionName}" ]]; then
        return ${E_ERROR}
    fi

    # set up the partition dataset name
    local _partitionDataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}"

    # unset the whitelist array
    zfs_unset_custom_array "${_partitionDataset}" "${ZFS_PROP_ROOT}.ptn_ip4whitelist"

    local _ip4
    for _ip4 in ${_ip4whitelist[@]}; do
        if is_valid_ip4 "${_ip4}"; then
            _ip4whitelistValidated+=("${_ip4}")

            e_note "${ip4}"
            # add it in to the zfs property list registry
            zfs_append_custom_array "${_partitionDataset}" "${ZFS_PROP_ROOT}.ptn_ip4whitelist" "${_ip4}"
        fi
    done

    # create the access file
    local _accessFileName=$( nginx_format_filename "ptn_${_partitionName}" )
    local _accessFilePath="${NGINX_ACCESSFILE_DIR}/${_accessFileName}"
    # include the path in ZFS
    nginx_create_access_file "${_accessFilePath}" _ip4whitelistValidated[@] "true"

    # include the access file in zfs
    zfs_set_property "${_partitionDataset}" "${ZFS_PROP_ROOT}:nginx_whitelist_accessfile" "${_accessFilePath}"

    # link it in to existing partition containers
    local _containerList=$( zfs_get_all_containers "${_partitionName}" )

    IFS=$'\n'
    for _containerDataset in ${_containerList}; do
        # get the zfs properties
        local _uuid=$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:host_hostuuid")

        # apply the whitelist to this container
        partition_ipv4whitelist_apply "${_uuid}" "${_partitionName}"
    done

    local _exitCode=0

    if [[ ${#_ip4whitelistValidated[@]} -gt 0 ]]; then
        # reload relevant files
        nginx_reload > /dev/null 2>&1
        _exitCode=$(( ${_exitCode} & $? ))
    fi

    return ${_exitCode}
}

# applies a partition whitelist to a specific container
function partition_ipv4whitelist_apply() {
    local _uuid="${1}"
    local _partitionName="${2}"

    local _containerDataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${_uuid}"

    # get the zfs properties
    local _containerName=$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:containername")
    local _anchorName=$( zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:anchorname" )

    # include the table data in zfs
    local _accessFilePath=$( zfs_get_property "${_containerDataset}" "${ZFS_PROP_ROOT}:nginx_whitelist_accessfile" )

    # get a list of ip addresses
    local _ip4_addresses=$(get_container_ip4_addr "${_partitionName}" "${_uuid}")

    # get the tcp and udp in ports for this container
    IFS=$'\n' local -a _tcpInPortsArray=$( zfs_get_custom_array "${_containerDataset}" "${ZFS_PROP_ROOT}.tcpinports" )
    IFS=$'\n' local -a _udpInPortsArray=$( zfs_get_custom_array "${_containerDataset}" "${ZFS_PROP_ROOT}.udpinports" )

    # flatten the arrays and separate by commas
    local _tcpInPorts=$( array_flatten _tcpInPortsArray[@] ',')
    local _udpInPorts=$( array_flatten _udpInPortsArray[@] ',')

    local -a _ip4_addrs
    local _i
    # loop over the addresses
    IFS=',' read -ra _ip4_addrs <<< "${_ip4_addresses}"
    for _i in "${_ip4_addrs[@]}"; do
        local _interface=$( extractFromIP4Addr "${_i}" "interface" )
        local _ip4=$( extractFromIP4Addr "${_i}" "ip4" )

        # whitelist this table along with tcp/udp in ports
        # TODO: open firewall ports for partitions
        #ipfw_open_ports "${_containerMountPoint}/root${CONTAINER_IPFW_PARTITION_SCRIPT}" "in"  "tcp" "${_interface}" "${_ip4}" "<${_tableName}>" "${_tcpInPorts}" "${_CONF_COMMON[firewallEnableLogging]}"
        #ipfw_open_ports "${_anchorName}" "in"  "udp" "${_interface}" "${_ip4}" "<${_tableName}>" "${_udpInPorts}" "${_CONF_COMMON[firewallEnableLogging]}"
    done

    # set up the http proxy
    local _url _urlDomain _urlDirectory
    local -a _urls=$( zfs_get_custom_array "${_containerDataset}" "${ZFS_PROP_ROOT}.url" )
    for _url in ${_urls[@]}; do
        _urlDomain=$(lcut ${_url} '/')

        _urlDirectory='/'
        # if the url contained a slash then grab the directory
        if string_contains_char "${_url}" '/'; then
            _urlDirectory="/$(rcut ${_url} '/')"
        fi

        local _servernameFile="$( nginx_format_filename "${_urlDomain}" )"

        # check if the HTTPS file exists
        if [[ -f "${NGINX_SERVERNAME_DIR}/https-${_servernameFile}" ]]; then
            # include the partition whitelist file for this url
            $(add_line_to_file_between_strings_if_not_exists "location ${_urlDirectory} {" "        include ${_accessFilePath};" "}" "${NGINX_SERVERNAME_DIR}/https-${_servernameFile}")
        fi

        # get the contents of the HTTP location block
        local _httpLocationBlock=$( get_data_between_strings "location ${_urlDirectory} {" "}" "$( cat "${NGINX_SERVERNAME_DIR}/http-${_servernameFile}" )" )

        # if it isnt a redirect then include this whitelist
        if [[ ! "${_httpLocationBlock}" =~ 'return 301 https://$host$request_uri;' ]]; then
            # include the partition whitelist
            $(add_line_to_file_between_strings_if_not_exists "location ${_urlDirectory} {" "        include ${_accessFilePath};" "}" "${NGINX_SERVERNAME_DIR}/http-${_servernameFile}")
        fi
    done
}

# clears the whitelist for the given partition
function partition_ipv4whitelist_clear() {
    local _partitionName="${1}"

    if [[ -z "${_partitionName}" ]]; then
        exit_with_error "Please include a partition to clear."
    fi

    # get a list of containers
    local _containerList=$( zfs_get_all_containers "${_partitionName}" )

    # get some file data from ZFS
    local _accessFilePath="$( zfs_get_property "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}" "${ZFS_PROP_ROOT}:nginx_whitelist_accessfile" )"

    # remove from zfs
    zfs_unset_custom_array "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}" "${ZFS_PROP_ROOT}.ptn_ip4whitelist"

    local _containerDataset
    IFS=$'\n'
    for _containerDataset in ${_containerList}; do
        # get the zfs properties
        local _uuid=$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:host_hostuuid")
        local _containerName=$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:containername")
        local _anchorName=$( zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:anchorname" )

        #  get a list of ip addresses
        local _ip4_addresses=$(get_container_ip4_addr "${_partitionName}" "${_uuid}")

        # remove the http proxy whitelist
        local _urlDomain _urlDirectory

        local -a _urls=$( zfs_get_custom_array "${_containerDataset}" "${ZFS_PROP_ROOT}.url" )
        for _url in ${_urls[@]}; do
            # split up the url into its domain and directory segments
            _urlDomain=$(lcut ${_url} '/')

            _urlDirectory=''
            # if the url contained a slash then grab the directory
            if string_contains_char "${_url}" '/'; then
                _urlDirectory="/$(rcut ${_url} '/')"
            fi

            # create the full path to the file
            local _servernameFile="$( nginx_format_filename "${_urlDomain}" )"

            # check if the HTTPS file exists
            if [[ -f "${NGINX_SERVERNAME_DIR}/https-${_servernameFile}" ]]; then
                # remove the include
                nginx_remove_include "${_accessFilePath}" "${NGINX_SERVERNAME_DIR}/https-${_servernameFile}"
            fi

            # get the contents of the HTTP location block
            local _httpLocationBlock=$( get_data_between_strings "location ${_urlDirectory} {" "}" "$( cat "${NGINX_SERVERNAME_DIR}/http-${_servernameFile}" )" )

            # now check the http server file
            if [[ -f "${NGINX_SERVERNAME_DIR}/https-${_servernameFile}" ]]; then
                # include the partition whitelist
                nginx_remove_include "${_accessFilePath}" "${NGINX_SERVERNAME_DIR}/https-${_servernameFile}"
            fi
        done
    done

    # remove the http proxy access file
    rm -f "${_accessFilePath}"

    # reload the l7 proxy

    e_note "Reloading Layer 7 proxy"
    if nginx_reload; then
        e_success "Success"
    else
        e_error "Failed"
    fi
}
