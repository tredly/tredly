#!/usr/bin/env bash

# lists the containers to stdout
function list_containers() {
    local _partitionName="${1}"
    local _containerGroupSearch="${2}"
    local _containerString=''
    local _sortBy
    local _partitionName

    local _datasets

    # if no partition name was passed, then use default partition
    if [[ -n "${_partitionName}" ]]; then
        # make sure this is a real partition name
        if [[ $( get_partition_names | grep "^${_partitionName}$" | wc -l ) -eq 0 ]]; then
            exit_with_error "Partition \"${_partitionName}\" does not exist."
        fi

        local _datasets=$( zfs_get_all_containers "${_partitionName}" )

        # print out the header
        if [[ -z "${_containerGroupSearch}" ]]; then
            e_header "Containers in Partition ${_partitionName}"
        else
            e_header "Containers in Partition ${_partitionName} in ContainerGroup ${_containerGroupSearch}"
        fi
    else
        # no partition given, so list all
        local _partitions=$( get_partition_names )

        local _partition
        for _partition in ${_partitions}; do
            local _partitionDS=$( zfs_get_all_containers "${_partition}" )
            _datasets=$( echo -e "${_datasets}\n${_partitionDS}" )
        done

        # print out the header
        e_header "Containers in All Partitions"
    fi

    # if the -s switch is given then grab what column to sort on
    if [[ -n "${_FLAGS[sortby]}" ]]; then
        # convert sortby to lowercase
        _sortBy=$(echo "${_FLAGS[sortby]}" | tr '[:upper:]' '[:lower:]')
    fi

    IFS=$'\n'
    local _dataset
    for _dataset in ${_datasets}; do
        # whether or not to print out this line
        local _printLine="true"

        # extract the partition name from the dataset name
        local _partition=$( rcut "${_dataset}" "${ZFS_TREDLY_PARTITIONS_DATASET}/" | cut -d '/' -f 1 )

        # loop over the containers and get their details
        local _uuid=$( echo "${_dataset}" | rev | cut -d'/' -f 1 | rev )
        local _containerName=$( zfs_get_property "${_dataset}" "${ZFS_PROP_ROOT}:containername" )
        local _buildEpoch=$( zfs_get_property "${_dataset}" "${ZFS_PROP_ROOT}:buildepoch" )
        local _containerVersion=$( zfs_get_property "${_dataset}" "${ZFS_PROP_ROOT}:containerversion" )
        local _containerGroupName=$( zfs_get_property "${_dataset}" "${ZFS_PROP_ROOT}:containergroupname" )
        local _persistentStorageId=$( zfs_get_property "${_dataset}" "${ZFS_PROP_ROOT}:persistentstorageid" )

        local _ip4_addr=$( zfs_get_property "${_dataset}" "${ZFS_PROP_ROOT}:ip4_addr" )
        local _ip4=$( extractFromIP4Addr "${_ip4_addr}" "ip4" )

        local _jid=$(jls -j trd-${_uuid} jid 2> /dev/null)

        # get state from ZFS
        local _state=$( zfs_get_property "${_dataset}" "${ZFS_PROP_ROOT}:containerstate" )

        # if the state is empty then check for jid
        if [[ "${_state}" == '-' ]]; then
            if [ -z "${_jid}" ]; then
                _state="down"
            else
                _state="up"
            fi
        fi


        # if the ip address was empty, replace with a dash
        if [[ -z "${_ip4}" ]]; then
            _ip4='-'
        fi

        # replace empty strings with dashes
        if [[ -z "${_persistentStorageId}" ]]; then
            _persistentStorageId='-'
        fi

        local _builtAt
        # convert some data
        if [[ -n "${_buildEpoch}" ]] && [[ "${_buildEpoch}" != '-' ]]; then
            _builtAt=$( date -r ${_buildEpoch} '+%d/%m/%Y %H:%M:%S %z' )
        else
            _builtAt="-"
        fi

        # if we were given a container group to search for then validate this container against it
        if [[ -n "${_containerGroupSearch}" ]] && [[ "${_containerGroupSearch}" != "${_containerGroupName}" ]]; then
            _printLine="false"
        fi

        if [[ "${_printLine}" == "true" ]]; then
            _containerString=$( echo "${_containerString}" ; printf "%s^%s^%s^%s^%s^%s^%s^%s\n" \
                                                        "${_partition}" "${_containerGroupName}" "${_containerName}" "${_uuid}" \
                                                        "${_ip4}" "${_state}" "${_builtAt}" "${_persistentStorageId}")
        fi
    done

    # if the user wanted to sort, then sort on the relevant column
    case "${_sortBy}" in
        partition)
            _containerString=$( echo "${_containerString}" | sort -t^ -k 1 )
        ;;
        containergroup)
            _containerString=$( echo "${_containerString}" | sort -t^ -k 2 )
        ;;
        name|containername)
            _containerString=$( echo "${_containerString}" | sort -t^ -k 3 )
        ;;
        uuid)
            _containerString=$( echo "${_containerString}" | sort -t^ -k 4 )
        ;;
        ip4)
            _containerString=$( echo "${_containerString}" | \
                           awk -F "^" '{print $5 " % " $0}' | \
                           sort -t. -n -k1,1 -k2,2 -k3,3 -k4,4 | sed 's/[^%]*% //' )
        ;;
        state)
            _containerString=$( echo "${_containerString}" | sort -t^ -k 4 )
        ;;
        created)
            _containerString=$( echo "${_containerString}" | sort -t^ -k 8 )
        ;;
        *)  # default - sort by partition then name
            _containerString=$( echo "${_containerString}" | sort -t^ -k 1 -k 3 )
        ;;
    esac

    local _numContainers=0
    if [[ -n "${_containerString}" ]]; then
        _numContainers=$( echo "${_containerString}" | wc -l )
        _numContainers=$(( ${_numContainers} - 1 ))
    fi

    # echo out the data
    echo -e "--------------------"
    printf "\e[1m"
    echo -e "Partition^ContainerGroup^ContainerName^UUID^IP4^State^Created^PersistentStorage\e[0m\e[39m\n${_containerString}" | column -ts^
    # and the number of containerss
    echo -e "--------------------\n`ltrim "${_numContainers}"` containers found."
}
