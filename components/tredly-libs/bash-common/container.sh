#!/usr/bin/env bash

# container.sh
#
# Contains reusable functions for container management
#

# runs a given command within the given container
function container_run_cmd() {
    local _uuid="${1}"
    local _command="${2}"
    
    # make sure the uuid exists
    if ! container_exists "${_uuid}"; then
        exit_with_error "No container with uuid ${_uuid} found"
    fi
    # run the command
    jexec trd-${_uuid} sh -c "${_command}"
    
    return $?
}

# Grants console access to a container
function container_console() {
    local _input="${1}"
    local _uuid

    if [[ -z "${_input}" ]]; then
        exit_with_error "Please enter a UUID."
    fi

    # work out whether this is a containerName or a uuid, and get the uuid if necessary
    if is_uuid "${_input}"; then
        _uuid="${_input}"
    else
        e_verbose "containerName received, converting \"${_input}\" to uuid"
        _uuid=$( get_uuid_from_container_name "${_input}" )
    fi

    jexec "trd-${_uuid}" login -f root
}

# returns the IPv4 address of a container
function get_container_ip4_addr() {
    local _partitionName="${1}"
    local _uuid="${2}"

    local _containerDataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${_uuid}"

    local output=$( zfs_get_property "${_containerDataset}" "${ZFS_PROP_ROOT}:ip4_addr" )
    echo "${output}"
}

# Returns the JID of a given container
function find_jail_id() {
    local jid=$(jls -j "trd-${1}" jid 2> /dev/null)

    if [[ $jid =~ ^[[:space:]]*([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return ${E_SUCCESS}
    else
        return ${E_ERROR}
    fi
}

# Starts a container
function container_start() {
    local _partitionName="${1}"
    local _uuid="${2}"
    local _ip4="${3}"
    local _ip6="${4}"
    local _bridgeIface="${5}"

    local _containerDataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${_uuid}"

    local _containerPath="${TREDLY_PARTITIONS_MOUNT}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${_uuid}"

    local _containerName=$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:containername")

    # set the ip addresses in the zfs datasets
    if [[ -n "${_ip4}" ]]; then
        zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:ip4_addr" "${_ip4}"
    fi

    if [[ -n "${_ip6}" ]]; then
        zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:ip6_addr" "${_ip6}"
    fi

    # extract info from ip4
    local _ip=$( extractFromIP4Addr "${_ip4}" "ip4" )
    local _cidr=$( extractFromIP4Addr "${_ip4}" "cidr" )

    # set up resolv.conf
    local -a _dnsServers
    IFS=$'\n' _dnsServers=($( zfs_get_custom_array "${_containerDataset}" "${ZFS_PROP_ROOT}.dns"))

    local _domainName=$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:domainname")

    if [[ -n "${_domainName}" ]] && [[ "${_domainName}" != '-' ]]; then
        echo "search ${_domainName}" > "${_containerPath}/root/etc/resolv.conf"
    fi

    for _dns in "${_dnsServers[@]}"; do
        echo "nameserver ${_dns}" >> "${_containerPath}/root/etc/resolv.conf"
    done

    # add self into /etc/hosts
    echo "${_ip} ${_containerName}.${_domainName}" >> "${_containerPath}/root/etc/hosts"

    # apply devfs rulesets
    devfs -m ${_containerPath}/root/dev rule -s $(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:devfs_ruleset") applyset

    jail -c vnet \
        name="trd-${_uuid}" \
        host.domainname="${_domainName}" \
        host.hostname="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:containername")" \
        path="${_containerPath}/root" \
        securelevel="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:securelevel")" \
        host.hostuuid="${_uuid}" \
        devfs_ruleset="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:devfs_ruleset")" \
        enforce_statfs="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:enforce_statfs")" \
        children.max="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:children_max")" \
        allow.set_hostname="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:allow_set_hostname")" \
        allow.sysvipc="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:allow_sysvipc")" \
        allow.raw_sockets="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:allow_raw_sockets")" \
        allow.chflags="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:allow_chflags")" \
        allow.mount="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:allow_mount")" \
        allow.mount.devfs="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:allow_mount_devfs")" \
        allow.mount.nullfs="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:allow_mount_nullfs")" \
        allow.mount.procfs="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:allow_mount_procfs")" \
        allow.mount.tmpfs="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:allow_mount_tmpfs")" \
        allow.mount.zfs="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:allow_mount_zfs")"  \
        allow.quotas="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:allow_quotas")" \
        allow.socket_af="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:allow_socket_af")" \
        exec.prestart="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:exec_prestart")" \
        exec.poststart="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:exec_poststart")" \
        exec.prestop="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:exec_prestop")" \
        exec.start="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:exec_start")" \
        exec.stop="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:exec_stop")" \
        exec.clean="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:exec_clean")" \
        exec.timeout="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:exec_timeout")" \
        exec.fib="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:exec_fib")" \
        stop.timeout="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:stop_timeout")" \
        mount.fstab="${_containerPath}/root/fstab" \
        mount.devfs="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:mount_devfs")" \
        mount.fdescfs="$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:mount_fdescfs")" \
        allow.dying \
        exec.consolelog="${TREDLY_LOG_MOUNT}/${_uuid}-console" \
        persist

    # set up the vnet interface
    local _hostIF=$( ifconfig epair create )
    # check that it exists
    if ! network_interface_exists "${_hostIF}"; then
        exit_with_error "Vnet host interface ${_containerIF} does not exist."
    fi

    # get the name of the jail epair from the host epair
    local _containerIF="$( rtrim "${_hostIF}" 'a')b"
    # check that it exists
    if ! network_interface_exists "${_containerIF}"; then
        exit_with_error "Vnet container interface ${_containerIF} does not exist."
    fi

    # set the mac addresses manually since vimage has problems with collisions
    ifconfig ${_hostIF} ether $( generate_mac_address )
    ifconfig ${_containerIF} ether $( generate_mac_address )

    # attach container interface to container
    ifconfig ${_containerIF} vnet trd-${_uuid}

    # rename container interface to something more meaningful
    jexec trd-${_uuid} ifconfig ${_containerIF} name ${VNET_CONTAINER_IFACE_NAME}

    # change our variable since the name changed
    _containerIF="${VNET_CONTAINER_IFACE_NAME}"

    # link the host interface to the bridge
    ifconfig ${_bridgeIface} addm ${_hostIF} up

    # indicate that this epair is paired with a container
    ifconfig ${_hostIF} description "Container ${_uuid}"

    # bring the host interface up
    ifconfig ${_hostIF} up

    local _ip6Address="$( ip6_find_available_address )"

    # set ip addresses for containers ip address
    jexec trd-${_uuid} ifconfig ${_containerIF} inet6 ${_ip6Address}
    jexec trd-${_uuid} ifconfig ${_containerIF} inet ${_ip}/${_cidr}

    local _defaultRoute

    # set default route
    if [[ "${_bridgeIface}" == "${_CONF_COMMON[wif]}" ]]; then
        # add a route to the local private network
        jexec trd-${_uuid} route add -net ${_CONF_COMMON[lifNetwork]}/${_CONF_COMMON[lif]} $( get_interface_ip4 "${_CONF_COMMON[wifPhysical]}")  > /dev/null 2>&1

        # get the host's default route and use that
        _defaultRoute=$(netstat -r4n | grep default | awk '{print $2}' )

        # add this ip address to the ipfw public ip table
        ipfw -q table 1 add ${_ip} > /dev/null 2>&1
        # add this epair to the ipfw public epair table
        ipfw -a table 2 add ${_hostIF} > /dev/null 2>&1
    else
        _defaultRoute="${_CONF_COMMON[vnetdefaultroute]}"
    fi

    jexec trd-${_uuid} route add default ${_defaultRoute} > /dev/null

    # set zfs properties
    zfs_set_property ${_containerDataset} "${ZFS_PROP_ROOT}:host_iface" "${_hostIF}"
    zfs_set_property ${_containerDataset} "${ZFS_PROP_ROOT}:container_iface" "${_containerIF}"

    # check if there were resource limits placed on this container
    local _maxCpu=$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:maxcpu")
    local _maxRam=$(zfs_get_property ${_containerDataset} "${ZFS_PROP_ROOT}:maxram")
    if [[ "${_maxRam}" != "-" ]]; then
        e_verbose "Applying memory resource limit of ${_maxRam}"
        rctl -a jail:trd-${_uuid}:memoryuse:deny=${_maxRam}
    fi
    if [[ "${_maxCpu}" != "-" ]]; then
        e_verbose "Applying cpu resource limit of ${_maxCpu}"
        rctl -a jail:trd-${_uuid}:pcpu:deny=${_maxCpu}
    fi

    return $?
}

# finds the uuid of a container when given the container name
function get_uuid_from_container_name() {
    local _partitionName="${1}"
    local _containerName="${2}"
    local _containerList=$( zfs_get_all_containers "${_partitionName}" )

    # loop over the containers and look for the container name
    IFS=$'\n'
    for _containerDataSet in ${_containerList}; do
        local _zfsData=$( zfs get -H -o value ${ZFS_PROP_ROOT}:host_hostuuid,${ZFS_PROP_ROOT}:containername ${_containerDataSet} )

        local _uuid=$( echo "${_zfsData}" | head -1 | tail -1 )
        local _zfsContainerName=$( echo "${_zfsData}" | head -2 | tail -1 )

        if [[ "${_containerName}" == "${_zfsContainerName}" ]]; then
            echo "${_uuid}"

            return $E_SUCCESS
        fi
    done

    echo ""
    return $E_ERROR
}

# checks to see if a container exists or not
function container_exists() {
    local _uuid="${1}"

    # if its empty then return false
    if [[ ${#_uuid} -eq 0 ]]; then
        return ${E_ERROR}
    fi

    # get a list of partitions
    local _partitions=$( get_partition_names )
    IFS=$'\n'
    local _partitionName
    for _partitionName in ${_partitions}; do
        local _output=$( zfs_get_property "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${_uuid}" "${ZFS_PROP_ROOT}:host_hostuuid" )
        # check the output
        if [[ -n ${_output} ]]; then
            return ${E_SUCCESS}
        fi
    done

    # default behaviour
    return ${E_ERROR}
}

# returns whether or not a container has been started
function container_started() {
    local _uuid="${1}"
    local _output=$( jls -j "trd-${_uuid}" jid 2> /dev/null )

    if [[ -n "${_output}" ]]; then
        # its up
        echo "true"
        return ${E_SUCCESS}
    fi

    # default behaviour
    echo "false"
    return ${E_ERROR}
}

# modifies the resource limits placed upon a container
function container_modify() {
    local _uuid="${1}"
    local _maxHdd="${2}"
    local _maxCpu="${3}"
    local _maxRam="${4}"
    local _ipv4Whitelist="${5}"

    local _exitCode=${E_SUCCESS}
    local _functionExitCode=${E_SUCCESS}

    #####
    # Pre flight checks

    # ensure the container is started before attempting to change resource limits
    if [[ $( container_started "${_uuid}" ) != "true" ]]; then
        exit_with_error "Container ${_uuid} does not exist"
    fi

    # find the partition this container is on
    local _partitionName=$( get_container_partition "${_uuid}" )

    if [[ -z "${_partitionName}" ]]; then
        exit_with_error "Could not find the partition for container ${_uuid}"
    fi

    # ensure received units are correct
    if [[ -n "${_maxHdd}" ]]; then
        if ! is_valid_size_unit "${_maxHdd}" "m,g"; then
            exit_with_error "Invalid HDD specification: ${_maxHdd}. Please use the format HDD=<size><unit>, eg HDD=1G."
        fi
    fi
    if [[ -n "${_maxCpu}" ]]; then
        if ! is_int "${_maxCpu}"; then
            exit_with_error "Invalid CPU specification: ${_maxCpu}. Please use the format CPU=<int>, eg CPU=1"
        fi
    fi
    if [[ -n "${_maxRam}" ]]; then
        if ! is_valid_size_unit "${_maxRam}" "m,g"; then
            exit_with_error "Invalid RAM specification: ${_maxRam}. Please use the format RAM=<size><unit>, eg RAM=1G."
        fi
    fi

    # End pre flight checks

    # form the dataset string
    local _containerDataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${_uuid}"

    # grab the container name
    local _containerName=$( zfs_get_property "${_containerDataset}" "${ZFS_PROP_ROOT}:containername" )

    e_header "Modifying existing container ${_containerName}"

    # set ZFS quota
    if [[ -n "${_maxHdd}" ]]; then
        e_note "Modifying HDD"
        if zfs_set_property ${_containerDataset} "quota" "${_maxHdd}"; then
            e_success "Success"
        else
            _exitCode=${E_ERROR}
            _functionExitCode=${E_ERROR}
            e_error "Failed"
        fi
    fi

    # set max ram
    if [[ -n "${_maxRam}" ]]; then
        e_note "Modifying RAM"
        rctl -a jail:trd-${_uuid}:memoryuse:deny=${_maxRam}
        # check exit code
        if [[ $? -eq 0 ]]; then
            # rctl succeeded, so set ZFS property
            if zfs_set_property ${_containerDataset} "${ZFS_PROP_ROOT}:maxram" "${_maxRam}"; then
                e_success "Success"
            else
                e_error "Failed"
                _exitCode=${E_ERROR}
                _functionExitCode=${E_ERROR}
            fi
        else
            _exitCode=${E_ERROR}
            _functionExitCode=${E_ERROR}
            e_error "Failed"
        fi
    fi

    # set max cpu
    if [[ -n "${_maxCpu}" ]]; then
        e_note "Modifying CPU"
        rctl -a jail:trd-${_uuid}:pcpu:deny=${_maxCpu}
        # check exit code
        if [[ $? -eq 0 ]]; then
            # rctl succeeded, so set ZFS property
            if zfs_set_property ${_containerDataset} "${ZFS_PROP_ROOT}:maxcpu" "${_maxCpu}"; then
                e_success "Success"
            else
                e_error "Failed"
                _exitCode=${E_ERROR}
                _functionExitCode=${E_ERROR}
            fi
        else
            _exitCode=${E_ERROR}
            e_error "Failed"
        fi
    fi

    # apply ip4 whitelisting
    _exitCode=${E_SUCCESS}
    if [[ -n "${_ipv4Whitelist}" ]]; then
        # set up nginx access file name and path
        local _accessFileName=$( nginx_format_filename "${_uuid}" )
        local _accessFilePath="${NGINX_ACCESSFILE_DIR}/${_accessFileName}"

        # check if it was a clear command
        if [[ "${_ipv4Whitelist}" == "clear" ]]; then
            e_note "Clearing whitelist from layer 4"

            if ipfw_delete_table "${_uuid}" "${CONTAINER_IPFW_WL_TABLE_CONTAINER}"; then
                e_success "Success"
            else
                e_error "Failed"
            fi

            e_note "Clearing whitelist from layer 7"
            if [[ -f "${_accessFilePath}" ]]; then
                if nginx_clear_access_file "${_accessFilePath}"; then
                    e_success "Success"
                else
                    e_error "Failed"
                fi
            fi

        else
            _exitCode=${E_SUCCESS}
            e_note "Applying whitelist to layer 4"
            # convert the whitelist into an array
            local -a _whitelistArray
            # check if there was more than 1 value
            if string_contains_char "${_ipv4Whitelist}" ","; then
                IFS=',' read -ra _whitelistArray <<< "${_ipv4Whitelist}"
            else
                _whitelistArray+=("${_ipv4Whitelist}")
            fi

            # delete the containers whitelist table first
            ipfw_delete_table "${_uuid}" "${CONTAINER_IPFW_WL_TABLE_CONTAINER}"

            # Set the whitelist
            local _ip4wl
            for _ip4wl in ${_whitelistArray[@]}; do
                # make sure its a valid network address
                # clean up any whitespace
                _ip4wl=$( ltrim "${_ip4wl}" " " )
                _ip4wl=$( rtrim "${_ip4wl}" " " )

                # extract the elements
                local _ip4Whitelist _cidrWhitelist
                IFS=/ read -r _ip4Whitelist _cidrWhitelist <<< "${_ip4wl}"

                # if cidr whitelist is empty then assume a host and set to 32
                if [[ -z "${_cidrWhitelist}" ]]; then
                    _cidrWhitelist=32
                fi

                # make sure the whitelist is a valid ip
                if is_valid_ip4 "${_ip4Whitelist}" && is_valid_cidr "${_cidrWhitelist}"; then
                    # add it to the table
                    ipfw_add_table_member "${_uuid}" "${CONTAINER_IPFW_WL_TABLE_CONTAINER}" "${_ip4Whitelist}/${_cidrWhitelist}"

                    _exitCode=$(( ${_exitCode} & $? ))
                else
                    _exitCode=${E_ERROR}
                fi
            done

            if [[ ${_exitCode} -eq 0 ]]; then
                e_success "Success"
                _exitCode=$(( ${_exitCode} & $? ))
            else
                e_error "Failed"
                _functionExitCode=${E_ERROR}
            fi


            _exitCode=${E_SUCCESS}
            e_note "Applying whitelist to layer 7"

            # remove the old access file
            if [[ -f "${_accessFilePath}" ]]; then
                nginx_clear_access_file "${_accessFilePath}"
                _exitCode=$(( ${_exitCode} & $? ))
            fi

            # recreate the file
            nginx_create_access_file "${_accessFilePath}" _whitelistArray[@]

            _exitCode=$(( ${_exitCode} & $? ))

            if [[ $? -eq 0 ]]; then
                e_success "Success"
            else
                e_error "Failed"
                _functionExitCode=${E_ERROR}
            fi
        fi

        # reload the layer 7 proxy
        e_note "Reloading layer 7 proxy"
        if nginx_reload; then
            e_success "Success"
        else
            e_error "Failed"
        fi
    fi

    return ${_functionExitCode}
}

## function to create a container
function container_create() {
    # some variables to hold values
    local tcpFwdPorts udpFwdPorts _projectname ip4_addr ip6_addr _startEpoch _endEpoch

    local _ignoreExisting="${1}"
    local _partitionName="${2}"

    if [[ -z "${_ignoreExisting}" ]]; then
        _ignoreExisting="false"
    fi

    # check if a partition was passed, and if not then use default as the partition name
    if [[ -z "${_partitionName}" ]]; then
        _partitionName="${TREDLY_DEFAULT_PARTITION}"
    fi

    _startEpoch=$( date +%s )

    # get the default release from ZFS
    local _defaultRelease=$( zfs_get_property "${ZFS_TREDLY_DATASET}" "${ZFS_PROP_ROOT}:default_release_name" )

    #### START PRE FLIGHT CHECKS
    # check that default release is set
    if [[ "${_defaultRelease}" == '-' ]] || [[ -z "${_defaultRelease}" ]]; then
        exit_with_error "Please set a default release to use with \"tredly modify defaultRelease\"."
    fi

    # make sure the requested partition exists
    if ! partition_exists "${_partitionName}"; then
        exit_with_error "Partition \"${_partitionName}\" does not exist."
    fi

    # if the user gave us ip4 addresses, then validate the input
    if [[ -n "${_FLAGS[ip4_addr]}" ]]; then
        # loop over the ip addresses given
        IFS=','
        for ip4_string in ${_FLAGS[ip4_addr]}; do
            # check that we have a cidr if they specified an ip4 addr
            if ! string_contains_char "${ip4_string}" "/"; then
                exit_with_error "ip4_addr ${ip4_string} missing cidr. Please use the format '<iface>|<ip>/<cidr>'. Eg. 'lo1|10.0.0.1/16'"
            fi

            # if ip4 addr specified, check that the ip and cidr (or netmask) is valid
            local checkIP4 checkCIDRorMask checkInterface
            checkIP4=$( extractFromIP4Addr "${ip4_string}" "ip4" )
            checkCIDRorMask=$( extractFromIP4Addr "${ip4_string}" "cidr" )
            checkInterface=$( extractFromIP4Addr "${ip4_string}" "interface" )

            if ! is_valid_ip4 "${checkIP4}"; then
                exit_with_error "IP Address '${checkIP4}' is invalid in ${ip4_string}"
            fi

            # validate the cidr/netmask
            if [[ ${#checkCIDRorMask} -le 2 ]] && ! is_valid_cidr "${checkCIDRorMask}"; then   #CIDR
                exit_with_error "CIDR '${checkCIDRorMask}' is invalid in ${ip4_string}"
            elif [[ ${#checkCIDRorMask} -gt 2 ]] && ! is_valid_ip4 "${checkCIDRorMask}"; then  #Netmask
                exit_with_error "Netmask '${checkCIDRorMask}' is invalid in ${ip4_string}"
            fi

            # validate the interface
            if ! network_interface_exists "${checkInterface}"; then
                exit_with_error "Interface '${checkInterface}' does not exist in ${ip4_string}"
            fi
        done
    fi

    if [[ -n "${_FLAGS[path]}" ]]; then
        _CONTAINER_CWD="$(rtrim ${_FLAGS[path]} /)/"
    else
        # use pwd to get the absolute path to the current directory
        local pwd=`pwd`
        _CONTAINER_CWD="${pwd}/"
    fi

    common_conf_validate wif,lifNetwork,lifCIDR,dns,lifNetwork

    # check that given network interfaces exist
    if ! network_interface_exists "${_CONF_COMMON[wif]}"; then
        exit_with_error "Network interface '${_CONF_COMMON[wif]}' does not exist"
    fi

    # set the tredlyfile
    tredlyFile="$(rtrim ${_CONTAINER_CWD} '/' )/Tredlyfile"

    # Parse the tredlyfile, and exit with an error if it doesnt exist
    if [[ ! -f "${tredlyFile}" ]]; then
        exit_with_error "No Tredlyfile found at ${tredlyFile}"
    elif ! tredlyfile_parse "${tredlyFile}"; then
        exit_with_error "Tredlyfile was invalid at ${_CONTAINER_CWD}"
    fi

    # make sure any sslcerts for layer 7 proxy actually exist
    local _cert _certList _src
    local _i=1

    # Check that certs actually exist
    for _cert in ${_CONF_TREDLYFILE_URLCERT[@]}; do
        if [[ -n "${_cert}" ]]; then

            # trim whitespace
            _cert=$(trim "${_cert}")

            # if first word of the source is "partition" then the file comes from the partition
            if [[ "${_cert}" =~ ^partition/ ]]; then
                local _certPath="$(rcut "${_cert}" "/" )"
                _src="${TREDLY_PARTITIONS_MOUNT}/${_partitionName}/${TREDLY_PTN_DATA_DIR_NAME}/${_certPath}/"
            else
                # comes from container
                _src="$(rtrim ${_CONTAINER_CWD} /)/${_cert}"
            fi

            # make sure directory exists
            if [[ ! -d "${_src}" ]]; then
                exit_with_error "Could not find SSL Certificate ${_src} in url${_i}Cert="
            fi
            # make sure server.crt exists
            if [[ ! -f "${_src}/server.crt" ]]; then
                exit_with_error "Could not find SSL Certificate ${_src}/server.crt in url${_i}Cert="
            fi
            # make sure server.key exists
            if [[ ! -f "${_src}/server.key" ]]; then
                exit_with_error "Could not find SSL Key ${_src}/server.key in url${_i}Cert="
            fi
        fi
        _i=$(( _i + 1))
    done
    
    for _cert in ${_CONF_TREDLYFILE_URLREDIRECTCERT[@]}; do
        if [[ -n "${_cert}" ]]; then

            # trim whitespace
            _cert=$(trim "${_cert}")

            # if first word of the source is "partition" then the file comes from the partition
            if [[ "${_cert}" =~ ^partition/ ]]; then
                local _certPath="$(rcut "${_cert}" "/" )"
                _src="${TREDLY_PARTITIONS_MOUNT}/${_partitionName}/${TREDLY_PTN_DATA_DIR_NAME}/${_certPath}/"
            else
                # comes from container
                _src="$(rtrim ${_CONTAINER_CWD} /)/${_cert}"
            fi

            # make sure directory exists
            if [[ ! -d "${_src}" ]]; then
                exit_with_error "Could not find SSL Certificate ${_src} in urlRedirectCert="
            fi
            # make sure server.crt exists
            if [[ ! -f "${_src}/server.crt" ]]; then
                exit_with_error "Could not find SSL Certificate ${_src}/server.crt in urlRedirectCert="
            fi
            # make sure server.key exists
            if [[ ! -f "${_src}/server.key" ]]; then
                exit_with_error "Could not find SSL Key ${_src}/server.key in urlRedirectCert="
            fi
        fi
    done


    #### END PRE FLIGHT CHECKS

    ## SET THE CONTAINERNAME
    local _container_name="${_CONF_TREDLYFILE[containerName]}"

    # override the containerName if we were given one on command line
    if [[ -n "${_FLAGS[containerName]}" ]]; then
        _container_name="${_FLAGS[containerName]}"
    fi

    # check if this container already exists, and exit if so, prevent container creation
    if [[ "${_ignoreExisting}" == "false" ]]; then
        local _uuid_check_existing=$( get_uuid_from_container_name "${_partitionName}" "${_container_name}" )

        if container_exists "${_uuid_check_existing}"; then
            exit_with_error "Container with name \"${_container_name}\" already exists in partition \"${_partitionName}\", try \"tredly replace container\""
        fi
    fi

    e_header "Creating Container - ${_container_name}"
    e_note "Creation started at `date -r ${_startEpoch} '+%d/%m/%Y %H:%M:%S %z'`"

    tcpOutPorts=$( array_flatten _CONF_TREDLYFILE_TCPOUT[@] ',')
    udpOutPorts=$( array_flatten _CONF_TREDLYFILE_UDPOUT[@] ',')
    tcpInPorts=$( array_flatten _CONF_TREDLYFILE_TCPIN[@] ',')
    udpInPorts=$( array_flatten _CONF_TREDLYFILE_UDPIN[@] ',')

    ## Set the IP and Interface
    declare -a _IP_ADDRESSES
    declare -a _CIDRs
    declare -a _INTERFACES

    # set the dns
    local dnsDisplay=''
    declare -a _dnsServers
    if [[ ${#_CONF_TREDLYFILE_CUSTOMDNS[@]} -gt 0 ]]; then
        _dnsServers=("${_CONF_TREDLYFILE_CUSTOMDNS[@]}")
    else
        # use the default dns
        _dnsServers=("${_CONF_COMMON_DNS[@]}")
    fi

    ip4_addr=""

    # set the ip4 address
    if [ -n "${_FLAGS[ip4_addr]}" ]; then
        # user specified ip address
        ip4_addr="${_FLAGS[ip4_addr]}"

        IFS=',' read -ra PAIR <<< "${_FLAGS[ip4_addr]}"

        regex="^([^|]+)\|(.+)/(.+)$"
        for i in "${PAIR[@]}"; do
            [[ $i =~ $regex ]]
            _INTERFACES=("${_INTERFACES[@]}" "${BASH_REMATCH[1]}")
            _IP_ADDRESSES=("${_IP_ADDRESSES[@]}" "${BASH_REMATCH[2]}")

            if [[ ${#BASH_REMATCH[3]} -gt 2 ]]; then
                local _cidr=$(netmask2cidr "${BASH_REMATCH[3]}" )
                _CIDRs=("${_CIDRs[@]}" "${_cidr}")
            else
                _CIDRs=("${_CIDRs[@]}" "${BASH_REMATCH[3]}")
            fi
        done
    else
        # auto assign it
        _IP_ADDRESSES=($(find_available_ip_address "${_CONF_COMMON[lifNetwork]}" "${_CONF_COMMON[lifCIDR]}"))
        _INTERFACES=("${_CONF_COMMON[lif]}")
        _CIDRs=("${_CONF_COMMON[lifCIDR]}")

        ip4_addr="${_INTERFACES[0]}|${_IP_ADDRESSES[0]}/${_CIDRs[0]}"
    fi

    # Sanity check: make sure the ip address is a valid ip
    if ! is_valid_ip4 "${_IP_ADDRESSES[0]}"; then
        exit_with_error "${_IP_ADDRESSES[0]} is not a valid ip4 address"
    fi

    # Sanity Check: ensure that the ip address we are going to use isnt already in use on that iface
    existingIP=$(ifconfig ${_CONF_COMMON[lif]} | grep " ${_IP_ADDRESSES[0]} " | wc -l)
    if [[ ${existingIP} -ne 0 ]]; then
        exit_with_error "IP Address ${ip4_addr} is already in use!"
    fi

    ip6_addr=""
    # set the ip6 address - this is implemented purely for poudriere - we dont use ip6 right now
    if [ -n "${_FLAGS[ip6_addr]}" ]; then
        # user specified ip address
        ip6_addr="${_FLAGS[ip6_addr]}"
    fi

    # output some info to the user
    local _ipv4display=$( extractFromIP4Addr "${ip4_addr}" "ip4")
    local _cidrdisplay=$( extractFromIP4Addr "${ip4_addr}" "cidr")
    e_note "${_container_name} allocated IP ${_ipv4display}/${_cidrdisplay}"
    local _dnsdisplay=$( array_flatten _dnsServers[@] ', ' )
    e_note "${_container_name} has DNS set to IP(s) ${_dnsdisplay}"

    ## Create the empty container with ip4 address and containerName
    uuid=$( zfs_create_container "${_container_name}" "${_partitionName}" "${_defaultRelease}" )

    if [[ -z ${uuid} ]]; then
        exit_with_error "Failed to create container. Have you run tredly init?"
    fi

    # set the dataset for this container
    local _container_dataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${uuid}"

    # now that we have a uuid we can trap SIGINT, and die gracefully
    #trap "sigint_destroy_container "${uuid} INT

    # set some defaults for now - these may be overwritten later by technicaloptions
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:securelevel" "2"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:devfs_ruleset" "4"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:enforce_statfs" "2"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:children_max" "0"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:allow_set_hostname" "0"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:allow_sysvipc" "0"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:allow_raw_sockets" "0"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:allow_chflags" "0"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:allow_mount" "0"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:allow_mount_devfs" "0"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:allow_mount_nullfs" "0"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:allow_mount_procfs" "0"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:allow_mount_tmpfs" "0"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:allow_mount_zfs" "0"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:allow_quotas" "0"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:allow_socket_af" "0"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:exec_prestart" "/usr/bin/true"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:exec_poststart" "/usr/bin/true"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:exec_prestop" "/usr/bin/true"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:exec_start" "/bin/sh /etc/rc"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:exec_stop" "/bin/sh /etc/rc.shutdown"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:exec_clean" "1"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:exec_timeout" "60"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:exec_fib" "0"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:stop_timeout" "30"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:mount_devfs" "0"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:mount_fdescfs" "1"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:ip4" "new"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:ip4_saddrsel" "1"

    # set properties for this container
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:domainname" "${_partitionName}.${_CONF_COMMON[tld]}"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:buildepoch" "${_startEpoch}"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:containername" "${_container_name}"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:containergroupname" "${_CONF_TREDLYFILE[containerGroup]}"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:persistentstorageuuid" "${_CONF_TREDLYFILE[persistentStorageUUID]}"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:partition" "${_partitionName}"
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:onstopscript" "${TREDLY_ONSTOP_SCRIPT}"

    # insert dns data
    for dnsServer in "${_dnsServers[@]}"; do
        zfs_append_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.dns" "${dnsServer}"
    done
    # insert the ports
    for port in "${_CONF_TREDLYFILE_TCPIN[@]}"; do
        zfs_append_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.tcpinports" "${port}"
    done
    for port in "${_CONF_TREDLYFILE_TCPOUT[@]}"; do
        zfs_append_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.tcpoutports" "${port}"
    done
    for port in "${_CONF_TREDLYFILE_UDPIN[@]}"; do
        zfs_append_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.udpinports" "${port}"
    done
    for port in "${_CONF_TREDLYFILE_UDPOUT[@]}"; do
        zfs_append_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.udpoutports" "${port}"
    done

    # set ip6 if it is defined
    if [[ -n "${ip6_addr}" ]]; then
        zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:ip6" "${ip6_addr}"
    fi

    e_note "Setting resource limits"

    # set cpu limiting
    local maxCpu="${_CONF_TREDLYFILE[maxCpu]}"
    if [[ -n "${maxCpu}" ]] && is_int "${maxCpu}"; then
        e_warning "maxCpu property value was set. Setting to ${maxCpu}%"
        zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:maxcpu" "${maxCpu}"
    else
        e_warning "maxCpu property value was not set. Defaulting to unlimited."
    fi

    # set ram limits
    local maxRam="${_CONF_TREDLYFILE[maxRam]}"
    if [[ -n "${maxRam}" ]] && is_int "${maxRam}"; then
        e_warning "maxRam property value was set. Setting to ${maxRam}GB"
        zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:maxram" "${maxRam}G"
    else
        e_warning "maxRam property value was not set. Defaulting to unlimited."
    fi

    ## Set the container maxHdd
    local maxHdd="${_CONF_TREDLYFILE[maxHdd]}"
    if [[ -n "${maxHdd}" ]] && is_int "${maxHdd}"; then

        e_warning "maxHdd property value was set. Setting to ${maxHdd}GB"

        # enable quotas for this container
        zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:allow_quotas" "1"
        # set the quota property
        zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:maxhdd" "${maxHdd}G"
    else
        e_warning "maxHdd property value was not set. Defaulting to unlimited."
    fi

    ## Set properties in 'technicalOptions'
    if [[ ${#_CONF_TREDLYFILE_TECHOPTIONS[@]} -gt 0 ]]; then
        regex="^([^ ]+)=([^ ]+)"

        for line in "${_CONF_TREDLYFILE_TECHOPTIONS[@]}"; do
            if string_contains_char "${line}" '='; then
                # key=value
                [[ $line =~ $regex ]]
                key="${BASH_REMATCH[1]}"
                value=$(ltrim "${BASH_REMATCH[2]}" /)
            else
                # key, no value
                key="${i}"
                value=""
            fi

            e_verbose "Setting technicaloption ${key}=${value}"
            zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:${key}" "${value}"
        done
    fi
    
    ## PERSISTENT STORAGE
    ## Check for persistent storage in the tredlyfile and allow zfs within the container if necessary
    if [[ -n "${_CONF_TREDLYFILE[persistentStorageUUID]}" ]]; then

        local _persistentStorageSuccess=0
        e_note "Creating persistent storage ${_CONF_TREDLYFILE[persistentStorageUUID]}"

        local _persistentDataset="${ZFS_TREDLY_PERSISTENT_DATASET}/${_CONF_TREDLYFILE[persistentStorageUUID]}"
        local _persistentMountpoint="${TREDLY_PERSISTENT_MOUNT}/${_CONF_TREDLYFILE[persistentStorageUUID]}"
        # append this data to ZFS properties
        zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:persistentmountpoint" "${_persistentMountpoint}"
        zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:persistentdataset" "${_persistentDataset}"

        # check if the dataset exists, and create it it doesnt
        local _datasetLines=$( zfs list | grep "^${_persistentDataset} " | wc -l )

        if [[ ${_datasetLines} -eq 0 ]]; then
            # dataset doesnt exist so create it
            e_verbose "Creating persistent storage dataset"

            # create the dataset
            zfs_create_dataset "${_persistentDataset}" "${_persistentMountpoint}"

            _persistentStorageSuccess=$(( ${_persistentStorageSuccess} & $? ))
        fi

        # check if a quota was given and set it
        if [[ -n "${_CONF_TREDLYFILE[persistentStorageGB]}" ]] && is_int "${_CONF_TREDLYFILE[persistentStorageGB]}"; then
            zfs_set_property "${_persistentDataset}" "quota" "${_CONF_TREDLYFILE[persistentStorageGB]}G"
            _persistentStorageSuccess=$(( ${_persistentStorageSuccess} & $? ))
        else
            e_warning "persistentStorageGB not set. Defaulting to unlimited."
        fi

        if [[ ${_persistentStorageSuccess} -eq 0 ]]; then
            e_success "Success"
        else
            e_error "Failed"
        fi
    fi

    # get the mountpoint
    local _containerMountPoint=$( zfs_get_property "${_container_dataset}" "${ZFS_PROP_ROOT}:mountpoint" )

    # Start the container
    container_start "${_partitionName}" "${uuid}" "${ip4_addr}" "${ip6_addr}" "${_INTERFACES[0]}"

    # get the jid
    local jid=$(find_jail_id "${uuid}")

    ## make sure the container mount point exists
    if [[ ! -d "${_containerMountPoint}" ]]; then
        exit_with_error "Something went wrong and the folder ${_containerMountPoint} does not exist!"
    fi

    ## Firewall Rules
    e_note "Configuring firewall for ${_container_name}"

    # loop over the ip addresses and add in the anchor rules
    IFS=',' read -ra PAIR <<< "${ip4_addr}"
    regex="^([^|]+)\|(.+)/(.+)$"
    local _exitCode=0
    for i in "${PAIR[@]}"; do
        [[ ${i} =~ ${regex} ]]

        # extract the data
        local _interface="${BASH_REMATCH[1]}"
        local _ip4="${BASH_REMATCH[2]}"
        local _cidr="${BASH_REMATCH[3]}"

        # dont add localhost to the rules
        if [[ "${_ip4}" =~ ^127\. ]]; then
            e_verbose "Localhost IP found: ${_ip4}, skipping..."
        else
            if [[ -n "${_CONF_TREDLYFILE[containerGroup]}" ]]; then
                # add this to the table members for all members of this containergroup
                ipfw_container_update_containergroup_members "${_CONF_TREDLYFILE[containerGroup]}" "${_partitionName}"
            fi

            # include the rules for ipv4 whitelist even if the table is empty
            # the table will be updated instead of the ruleset whenever the whitelist changes
            ipfw_open_port "${uuid}" "in" "tcp" "${VNET_CONTAINER_IFACE_NAME}" "'table(2)'" "${_ip4}" "${tcpInPorts}"
            ipfw_open_port "${uuid}" "in" "udp" "${VNET_CONTAINER_IFACE_NAME}" "'table(2)'" "${_ip4}" "${udpInPorts}"

            # set the partition whitelist table up in this new container
            ipfw_container_set_partition_whitelist "${uuid}" "${_partitionName}"

            # Set the default rules for the container whitelist. If there are no ips within the table then the
            # rule will be ignored
            ipfw_open_port "${uuid}" "in" "tcp" "${VNET_CONTAINER_IFACE_NAME}" "'table(3)'" "${_ip4}" "${tcpInPorts}"
            ipfw_open_port "${uuid}" "in" "udp" "${VNET_CONTAINER_IFACE_NAME}" "'table(3)'" "${_ip4}" "${udpInPorts}"

            # if we were given a list of ip addresses to whitelist then add them in
            if [[ "${#_CONF_TREDLYFILE_IP4WHITELIST[@]}" -gt 0 ]]; then

                # loop over the whitelist from the tredlyfile
                for _ip4Whitelist in ${_CONF_TREDLYFILE_IP4WHITELIST[@]}; do
                    # clean up any whitespace
                    _ip4Whitelist=$( ltrim "${_ip4Whitelist}" " " )
                    _ip4Whitelist=$( rtrim "${_ip4Whitelist}" " " )

                    # extract the elements
                    IFS=/ read -r _ip4Whitelist _cidrWhitelist <<< "${_ip4Whitelist}"

                    # if cidr whitelist is empty then assume a host and set to 32
                    if [[ -z "${_cidrWhitelist}" ]]; then
                        _cidrWhitelist=32
                    fi

                    # make sure that we dont proxy internal ip addresses and that the whitelist is a valid ip
                    if is_valid_ip4 "${_ip4Whitelist}" && is_valid_cidr "${_cidrWhitelist}"; then

                        # add it to the table
                        if ! ipfw_add_table_member "${uuid}" "${CONTAINER_IPFW_WL_TABLE_CONTAINER}" "${_ip4Whitelist}/${_cidrWhitelist}"; then
                            e_error "Failed to add container ip4whitelist member ${_ip4Whitelist}/${_cidrWhitelist}"
                        fi
                    else
                        e_verbose "Skipping invalid whitelisted ip address ${_ip4Whitelist}/${_cidrWhitelist}"
                    fi
                done
            elif [[ -n "${_CONF_TREDLYFILE[containerGroup]}" ]]; then
                # allow communication in from members
                ipfw_open_port "${uuid}" "in" "tcp" "${VNET_CONTAINER_IFACE_NAME}" "'table(1)'" "${_ip4}" "${tcpInPorts}"
                _exitCode=$(( $? & ${_exitCode} ))
                ipfw_open_port "${uuid}" "in" "udp" "${VNET_CONTAINER_IFACE_NAME}" "'table(1)'" "${_ip4}" "${udpInPorts}"
                _exitCode=$(( $? & ${_exitCode} ))
            else
                # open IN ports from any
                ipfw_open_port "${uuid}" "in" "tcp" "${VNET_CONTAINER_IFACE_NAME}" "any" "${_ip4}" "${tcpInPorts}"
                _exitCode=$(( $? & ${_exitCode} ))
                ipfw_open_port "${uuid}" "in" "udp" "${VNET_CONTAINER_IFACE_NAME}" "any" "${_ip4}" "${udpInPorts}"
                _exitCode=$(( $? & ${_exitCode} ))
            fi

            # if user didn't request "any" out for tcp, then allow 80 (http), and 443 (https) out by default
            if ! array_contains_substring _CONF_TREDLYFILE_TCPOUT[@] '^any$'; then
                ipfw_open_port "${uuid}" "out" "tcp" "${VNET_CONTAINER_IFACE_NAME}" "${_ip4}" "any" "80"
                _exitCode=$(( $? & ${_exitCode} ))
                ipfw_open_port "${uuid}" "out" "tcp" "${VNET_CONTAINER_IFACE_NAME}" "${_ip4}" "any" "443"
                _exitCode=$(( $? & ${_exitCode} ))
            fi
            # if user didn't request "any" out for udp, then allow 53 (dns) out by default
            if ! array_contains_substring _CONF_TREDLYFILE_UDPOUT[@] '^any$'; then
                ipfw_open_port "${uuid}" "out" "udp" "${VNET_CONTAINER_IFACE_NAME}" "${_ip4}" "any" "53"
                _exitCode=$(( $? & ${_exitCode} ))
            fi
            # allow out ports as specified
            ipfw_open_port "${uuid}" "out" "tcp" "${VNET_CONTAINER_IFACE_NAME}" "${_ip4}" "any" "${tcpOutPorts}"
            _exitCode=$(( $? & ${_exitCode} ))
            ipfw_open_port "${uuid}" "out" "udp" "${VNET_CONTAINER_IFACE_NAME}" "${_ip4}" "any" "${udpOutPorts}"
            _exitCode=$(( $? & ${_exitCode} ))

            # open port 80 if a urlcert is blank
            if array_contains_substring _CONF_TREDLYFILE_URLCERT[@] "^$"; then
                ipfw_open_port "${uuid}" "in" "tcp" "${VNET_CONTAINER_IFACE_NAME}" "${_CONF_COMMON[httpproxy]}" "${_ip4}" "80"
                _exitCode=$(( $? & ${_exitCode} ))
            fi
            # open port 443 if a urlcert is set
            if array_contains_substring _CONF_TREDLYFILE_URLCERT[@] "^.+$"; then
                ipfw_open_port "${uuid}" "in" "tcp" "${VNET_CONTAINER_IFACE_NAME}" "${_CONF_COMMON[httpproxy]}" "${_ip4}" "443"
                _exitCode=$(( $? & ${_exitCode} ))
            fi

            # and port 53 to the proxy
            ipfw_open_port "${uuid}" "out" "udp" "${VNET_CONTAINER_IFACE_NAME}" "${_ip4}" "${_CONF_COMMON[httpproxy]}" "53"
            _exitCode=$(( $? & ${_exitCode} ))

            # and this container can talk to itself on any port
            ipfw_open_port "${uuid}" ""  "udp" "${VNET_CONTAINER_IFACE_NAME}" "${_ip4}" "${_ip4}" "any"
            _exitCode=$(( $? & ${_exitCode} ))
            ipfw_open_port "${uuid}" "" "tcp" "${VNET_CONTAINER_IFACE_NAME}" "${_ip4}" "${_ip4}" "any"
            _exitCode=$(( $? & ${_exitCode} ))

            # and on localhost
            ipfw_open_port "${uuid}" ""  "ip" "lo0" "any" "any" "any"
            _exitCode=$(( $? & ${_exitCode} ))
        fi
    done

    if [[ ${_exitCode} -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi

    # update the pkg info
    e_note "Updating package database"
    pkg update
    if [[ $? -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi

    # copy the repo database into this container so we dont have to download meta etc
    e_note "Updating container's pkg catalogue..."
    cp /var/db/pkg/repo-FreeBSD.sqlite ${_containerMountPoint}/root/var/db/pkg

    if [[ $? -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi

    # Run the STARTUP commands
    if [[ ${#_CONF_TREDLYFILE_STARTUP[@]} -gt 0 ]]; then
        e_verbose "Running the start up commands... "

        # loop over the lines in the array - no need to sanitise as its already been done
        for line in "${_CONF_TREDLYFILE_STARTUP[@]}"; do
            key="${line%%=*}"
            value="${line#*=}"

            e_verbose "Running startup command '${line}'"
            case "${key}" in
                onStart)        # standard shell command
                    e_note "Running onStart command: \"${value}\""
                    jexec ${jid} sh -c "${value}"
                    if [[ $? -eq 0 ]]; then
                        e_success "Success"
                    else
                        e_error "Failed"
                    fi
                    ;;
                installPackage) # install some packages
                    e_note "Installing: ${value} and its dependencies"

                    # mount the host's pkg cache
                    # this will eventually be removed in favour of poudriere
                    mount_nullfs /var/cache/pkg ${_containerMountPoint}/root/var/cache/pkg

                    # install the package
                    yes y | pkg -j "trd-${uuid}" install -y "${value}"
                    local _pkgRetVal=$?

                    # unmount the host's pkg cache
                    umount ${_containerMountPoint}/root/var/cache/pkg

                    if [[ ${_pkgRetVal} -eq 0 ]]; then
                        e_success "Success"
                    else
                        e_error "Failed"
                    fi

                    # workarounds for packages
                    if [[ "${value}" =~ .*postgresql[0-9]*-server.* ]]; then
                        # extract the ip address info that we're interested in
                        local ipPart3=$( echo "${_IP_ADDRESSES[0]}" | cut -d . -f 3 )
                        local ipPart4=$( echo "${_IP_ADDRESSES[0]}" | cut -d . -f 4 )

                        # form the new uid
                        local newUID="70"${ipPart3}${ipPart4}
                        # run the workaround
                        workaround_postgresql-server_start "${newUID}" "${jid}"
                    fi
                    ;;
                fileFolderMapping)  # copy some files or directories into the container
                    # trim whitespace
                    value=$(trim "${value}")
                    regex="^([^ ]+)[[:space:]]([^ ]+)"
                    [[ $value =~ $regex ]]
                    # trim leading slashes
                    local src=$(ltrim "${BASH_REMATCH[1]}" /)
                    local dest=$(ltrim "${BASH_REMATCH[2]}" /)

                    # if first word of the source is "partition" then the file comes from the partition
                    if [[ "${src}" =~ ^partition/ ]]; then
                        e_note "Copying Partition Data \"/$(rcut "${src}" "/" )\" to \"/${dest}\""

                        src="${TREDLY_PARTITIONS_MOUNT}/${_partitionName}/${TREDLY_PTN_DATA_DIR_NAME}/$(rcut "${src}" "/" )/"
                    else
                        e_note "Copying Container Data \"/${src}\" to \"/${dest}\""
                        src="$(rtrim ${_CONTAINER_CWD} /)/${src}"
                    fi

                    # copy the data
                    copy_files "${src}" "${_containerMountPoint}/root/${dest}"

                    if [[ $? -eq 0 ]]; then
                        e_success "Success"
                    else
                        e_error "Failed"
                    fi
                    ;;
                persistentMountPoint)
                    e_note "Attaching persistent storage \"${value}\""

                    # add in the full path for the mountpoint
                    local _strippedValue=$( ltrim "${value}" '/' )
                    local _persistentMountPoint="${_containerMountPoint}/root/${_strippedValue}"

                    zfs_mount_nullfs_in_jail "${_persistentDataset}" "${_persistentMountPoint}"

                    if [[ $? -eq 0 ]]; then
                        e_success "Success"
                    else
                        e_error "Failed"
                    fi
                    ;;
                *)
                    e_warning "Unknown command: ${line}"
                    ;;
            esac
        done
    fi

    e_note "Creating onStop script"
    local _exitCode=0
    # create an onstop script to run when the container shuts down
    if [[ ${#_CONF_TREDLYFILE_SHUTDOWN[@]} -gt 0 ]]; then
        local _onStopFile="${_containerMountPoint}/root${TREDLY_ONSTOP_SCRIPT}"

        # echo in the shebang
        echo '#!/usr/bin/env sh' >> "${_onStopFile}"

        # echo in the commands
        for line in "${_CONF_TREDLYFILE_SHUTDOWN[@]}"; do
            key=${line%%=*}
            cmd="${line#*=}"

            echo "${cmd}" >> "${_onStopFile}"

            _exitCode=$(( $? & ${_exitCode} ))
        done

        # set it as executable and owned by root
        chown root "${_onStopFile}"
        _exitCode=$(( $? & ${_exitCode} ))
        chmod 700 "${_onStopFile}"
        _exitCode=$(( $? & ${_exitCode} ))

        if [[ ${_exitCode} -eq 0 ]]; then
            e_success "Success"
        else
            e_error "Failed"
        fi
    fi

    # add the hostname into dns
    e_note "Adding container to DNS"
    if unbound_insert_a_record "${_container_name}.${_partitionName}.${_CONF_COMMON[tld]}" "${_IP_ADDRESSES[0]}" "${uuid}"; then
        # append it to zfs
        zfs_append_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.registered_dns_names" "${_container_name}.${_partitionName}.${_CONF_COMMON[tld]}"

        e_success "Success"
    else
        e_error "Failed"
    fi

    ## HTTP PROXY/UNBOUND CONFIG
    if [[ ${#_CONF_TREDLYFILE_URL[@]} -gt 0 ]]; then

        # include the current location of nginx files so that we can destroy cleanly
        zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:nginx_upstream_dir" "${NGINX_UPSTREAM_DIR}"
        zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:nginx_servername_dir" "${NGINX_SERVERNAME_DIR}"
        zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:nginx_accessfile_dir" "${NGINX_ACCESSFILE_DIR}"
        local src

        # loop over the URLCERTs and install them
        for _cert in ${_CONF_TREDLYFILE_URLCERT[@]}; do
            if [[ -n "${_cert}" ]]; then
                # trim whitespace
                _cert=$(trim "${_cert}")

                e_note "Setting up SSL Cert \"${_cert}\" for layer 7 proxy"
                nginx_copy_cert "${_cert}" "${_partitionName}"

                if [[ $? -eq 0 ]]; then
                    e_success "Success"
                else
                    e_error "Failed"
                fi
            fi
        done

        # loop over the URLREDIRECTCERTs and install them
        for _cert in ${_CONF_TREDLYFILE_URLREDIRECTCERT[@]}; do
            if [[ -n "${_cert}" ]]; then
                # trim whitespace
                _cert=$(trim "${_cert}")

                e_note "Setting up Redirect SSL Cert \"${_cert}\" for layer 7 proxy"
                nginx_copy_cert "${_cert}" "${_partitionName}"

                if [[ $? -eq 0 ]]; then
                    e_success "Success"
                else
                    e_error "Failed"
                fi
            fi
        done
        e_note "Configuring layer 7 Proxy (HTTP) for ${_container_name}"
        # loop over the urls, getting their filenames and adding in to each of the http proxy files
        for i in "${!_CONF_TREDLYFILE_URL[@]}"; do
            # get the url and associated info
            local _url="${_CONF_TREDLYFILE_URL[${i}]}"
            local _urlCert="${_CONF_TREDLYFILE_URLCERT[${i}]}"
            local _urlWebsocket="${_CONF_TREDLYFILE_URLWEBSOCKET[${i}]}"
            local _urlMaxFileSize="${_CONF_TREDLYFILE_URLMAXFILESIZE[${i}]}"

            # trim urlcert down to the last dir name and add partition name so that partitions dont step on each others certs
            if [[ -n "${_urlCert}" ]]; then
                _urlCert="$(echo "${_urlCert}" | rev | cut -d '/' -f 1 | rev )"
            fi
            _urlDomain=$(lcut ${_url} '/')

            _urlDirectory=''
            # if the url contained a slash then grab the directory
            if string_contains_char "${_url}" '/'; then
                _urlDirectory=$(rcut ${_url} '/')
            fi

            # remove any trailing or leading spaces
            url=$(ltrim "${_url}" ' ')
            url=$(rtrim "${_url}" ' ')

            # add the url and cert into zfs
            zfs_append_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.url" "${_url}"
            zfs_append_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.url_cert" "${_urlCert}"

            # add the line in to the DNS config
            if unbound_insert_a_record "${_urlDomain}" "${_CONF_COMMON[httpproxy]}" "${uuid}"; then
                e_verbose "Inserted dns record: ${_urlDomain} ${_CONF_COMMON[httpproxy]}"
                zfs_append_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.registered_dns_names" "${_urlDomain}"
            else
                e_error "Failed to insert DNS record for ${_urlDomain} ${_CONF_COMMON[httpproxy]}"
            fi

            # create the directory if it doesnt already exist
            if [[ ! -d "${NGINX_UPSTREAM_DIR}" ]]; then
                mkdir -p "${NGINX_UPSTREAM_DIR}"

                if [[ $? -ne 0 ]]; then
                    e_error "Failed to create upstream dir ${NGINX_UPSTREAM_DIR}"
                else
                    e_verbose "Created upstream dir ${NGINX_UPSTREAM_DIR}"
                fi
            fi

            # append the partition name if the urlcert was set
            if [[ -n "${_urlCert}" ]]; then
                _urlCert="${_partitionName}/${_urlCert}"
            fi

            # add the url
            nginx_add_url "${_url}" "${_urlCert}" "${_urlWebsocket}" "${_urlMaxFileSize}" "${_IP_ADDRESSES[0]}" "${uuid}" "${_container_dataset}" _CONF_TREDLYFILE_IP4WHITELIST[@]

            local _redirectToProto="http"
            # work out if this is being redirected to a https location
            if [[ -n "${_urlCert}" ]]; then
                _redirectToProto="https"
            fi
            # and the redirects to it
            IFS=' '
            local n=1
            local i=0

            local _redirectUrlCert
            for _redirectUrl in ${_CONF_TREDLYFILE_URLREDIRECT[$(( ${i} + 1 ))]}; do

                # extract the cert from the array and the space separated string
                _redirectUrlCert=$( echo "${_CONF_TREDLYFILE_URLREDIRECTCERT[$(( ${i} + 1 ))]}" | cut -d ' ' -f ${n} )

                # trim urlcert down to the last dir name and add partition name so that partitions dont step on each others certs
                if [[ -n "${_redirectUrlCert}" ]]; then
                    # add the partition and trim out the string until we have the last directory
                    _redirectUrlCert="$(echo "${_redirectUrlCert}" | rev | cut -d '/' -f 1 | rev )"
                fi

                # set the url cert as blank if it was set to null
                if [[ "${_redirectUrlCert}" == 'null' ]]; then
                    _redirectUrlCert=''
                fi
                
                # add the redirection
                nginx_add_redirect_url "${_redirectUrl}" "${_redirectToProto}://${_url}" "${_redirectUrlCert}" "${_partitionName}"

                # register the redirect url within zfs
                zfs_append_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.redirect_url" "${_redirectUrl}"
                zfs_append_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.redirect_url_cert" "${_redirectUrlCert}"

                n=$(( ${n} + 1 ))
            done
            i=$(( ${i} + 1 ))
        done

        # reload nginx config
        if nginx_reload; then
            e_success "Success"
        else
            e_error "Failed"
        fi
    fi

    # Check if there was a whitelist applied to the partition this container resides in
    local _partitionDataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}"
    if [[ -n "$( zfs_get_custom_array "${_partitionDataset}" "${ZFS_PROP_ROOT}.ptn_ip4whitelist" )" ]]; then
        e_note "Applying partition whitelist"

        if partition_ipv4whitelist_apply "${uuid}" "${_partitionName}"; then
            e_success "Success"
        else
            e_error "Failed"
        fi
    fi

    # Add in the layer 4 proxying stuff if the container requested it
    if [[ "${_CONF_TREDLYFILE[layer4Proxy]}" == "yes" ]]; then
        e_note "Configuring layer 4 Proxy (tcp/udp) for ${_container_name}"

        local _exitCode=0

        local _tcpPort _udpPort

        # loop over tcp ports, adding in their entries
        for _tcpPort in "${_CONF_TREDLYFILE_TCPIN[@]}"; do
            # clean up whitespace on the port
            _tcpPort=$(ltrim "${_tcpPort}" ' ')
            _tcpPort=$(rtrim "${_tcpPort}" ' ')

            # add a new forward line to ipfw
            echo "redirect_port tcp ${_IP_ADDRESSES[0]}:${_tcpPort} ${_tcpPort} \\" >> "${IPFW_FORWARDS}"

            # register this port in ZFS
            zfs_append_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.layer4proxytcp" "${_IP_ADDRESSES[0]}:${_tcpPort}"

            _exitCode=$(( ${_exitCode} & $? ))
        done

        # loop over udp ports, adding in their entries
        for _udpPort in "${_CONF_TREDLYFILE_UDPIN[@]}"; do
            # clean up whitespace on the port
            _udpPort=$(ltrim "${_udpPort}" ' ')
            _udpPort=$(rtrim "${_udpPort}" ' ')

            # add a new forward line to ipfw
            echo "redirect_port tcp ${_IP_ADDRESSES[0]}:${_tcpPort} ${_tcpPort}\\" >> "${IPFW_FORWARDS}"

            # register this port in ZFS
            zfs_append_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.layer4proxyudp" "${_IP_ADDRESSES[0]}:${_udpPort}"

            _exitCode=$(( ${_exitCode} & $? ))
        done

        # Run the layer 4 proxy script to update the ports
        sh "${IPFW_FORWARDS}"
        _exitCode=$(( ${_exitCode} & $? ))
        if [[ ${_exitCode} -eq 0 ]]; then
            e_success "Success"
        else
            e_error "Failed"
        fi
    fi

    # Reload DNS
    e_note "Reloading DNS server"
    if unbound_reload; then
        e_success "Success"
    else
        e_error "Failed"
    fi

    # calculate the time taken to run this script
    _endEpoch=$( date +%s )
    # set this in zfs properties in case we want to use it later
    zfs_set_property "${_container_dataset}" "${ZFS_PROP_ROOT}:endepoch" "${_endEpoch}"
    _scriptTime=$(( ${_endEpoch} - ${_startEpoch} ))

    e_success "Creation completed at `date -r ${_endEpoch} '+%d/%m/%Y %H:%M:%S %z'`"
    e_success "Total time taken: ${_scriptTime} seconds"
}

# Destroys a container
function destroy_container() {

    local input="${1}"
    local _partitionName="${2}"

    # PRE FLIGHT CHECKS

    if [[ -z "${input}" ]]; then
        exit_with_error "No uuid specified."
    fi
    if [[ -z "${_partitionName}" ]]; then
        exit_with_error "No partition name specified."
    fi

    # work out whether this is a containerName or a uuid, and get the uuid if necessary
    local uuid
    if is_uuid "${input}"; then
        uuid="${input}"
    else
        e_verbose "containerName received, converting \"${input}\" to uuid"
        uuid=$( get_uuid_from_container_name "${_partitionName}" "${input}" )
    fi

    # make sure the container exists
    if [[ $( zfs list "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${uuid}" 2> /dev/null | wc -l ) -eq 0 ]]; then
        e_error "Container with uuid ${uuid} not found on partition ${_partition}."
    fi

    local _containerName=$( zfs_get_property "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${uuid}" "${ZFS_PROP_ROOT}:containername" )
    local _containerStarted=$( container_started "${uuid}" )
    local ip4_addresses local _startEpoch _endEpoch _reloadNginx="false"
    local _INTERFACES _IP_ADDRESSES _CIDRs


    _startEpoch=$( date +%s )

    if [[ -z "${uuid}" ]]; then
        exit_with_error "UUID is required."
    fi

    # END PRE FLIGHT CHECKS

    e_header "Destroying Container - ${_containerName}"
    e_note "Destruction started at `date -r ${_startEpoch} '+%d/%m/%Y %H:%M:%S %z'`"

    ## Find container IP address(es)
    ip4_addresses=$( get_container_ip4_addr "${_partitionName}" "${uuid}" )

    # set the dataset for this container
    local _container_dataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${uuid}"

    # get any useful info from this dataset before we destroy it
    local _domainName=$( zfs_get_property "${_container_dataset}" "${ZFS_PROP_ROOT}:domainname" )
    local _buildEpoch=$( zfs_get_property "${_container_dataset}" "${ZFS_PROP_ROOT}:buildepoch" )
    local _containerMountPoint=$( zfs_get_property "${_container_dataset}" "${ZFS_PROP_ROOT}:mountpoint" )
    local rdrAnchorName=$( zfs_get_property "${_container_dataset}" "${ZFS_PROP_ROOT}:rdranchorname" )
    local _persistentStorageUUID=$( zfs_get_property "${_container_dataset}" "${ZFS_PROP_ROOT}:persistentstorageuuid" )
    local _persistentMountpoint=$( zfs_get_property "${_container_dataset}" "${ZFS_PROP_ROOT}:persistentmountpoint" )
    local _persistentDataset=$( zfs_get_property "${_container_dataset}" "${ZFS_PROP_ROOT}:persistentdataset" )
    local _onStopScript=$( zfs_get_property "${_container_dataset}" "${ZFS_PROP_ROOT}:onstopscript" )
    local _nginxUpstreamDir=$( zfs_get_property "${_container_dataset}" "${ZFS_PROP_ROOT}:nginx_upstream_dir" )
    local _nginxServerNameDir=$( zfs_get_property "${_container_dataset}" "${ZFS_PROP_ROOT}:nginx_servername_dir" )
    local _nginxAccessFileDir=$( zfs_get_property "${_container_dataset}" "${ZFS_PROP_ROOT}:nginx_accessfile_dir" )
    local _hostIface=$( zfs_get_property "${_container_dataset}" "${ZFS_PROP_ROOT}:host_iface" )
    local _containerIface=$( zfs_get_property "${_container_dataset}" "${ZFS_PROP_ROOT}:container_iface" )
    local _containerGroupName=$( zfs_get_property "${_container_dataset}" "${ZFS_PROP_ROOT}:containergroupname" )

    # and arrays
    IFS=$'\n' local -a _urls=($( zfs_get_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.url" ))
    IFS=$'\n' local -a _urlCerts=($( zfs_get_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.url_cert" ))
    IFS=$'\n' local -a _redirectUrls=($( zfs_get_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.redirect_url" ))
    IFS=$'\n' local -a _redirectUrlCerts=($( zfs_get_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.redirect_url_cert" ))
    IFS=$'\n' local -a _nginxServerNameFiles=($( zfs_get_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.nginx_servername" ))
    IFS=$'\n' local -a _nginxUpstreamFiles=($( zfs_get_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.nginx_upstream" ))
    IFS=$'\n' local -a _layer4ProxyTCP=($( zfs_get_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.layer4proxytcp" ))
    IFS=$'\n' local -a _layer4ProxyUDP=($( zfs_get_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.layer4proxyudp" ))

    # get the ip4 addresses
    if [[ -n "${ip4_addresses}" ]]; then
        IFS=',' read -ra PAIR <<< "${ip4_addresses}"
        regex="^([^|]+)\|(.+)/(.+)$"
        for i in "${PAIR[@]}"; do
            [[ $i =~ $regex ]]
            _INTERFACES=("${_INTERFACES[@]}" "${BASH_REMATCH[1]}")
            _IP_ADDRESSES=("${_IP_ADDRESSES[@]}" "${BASH_REMATCH[2]}")
            _CIDRs=("${_CIDRs[@]}" "${BASH_REMATCH[3]}")
        done
    fi

    if [[ -z "${ip4_addresses}" ]]; then
        e_warning "Container does not have IP address, or does not exist."
    fi

    e_note "${_containerName} has IP address ${_IP_ADDRESSES[0]}/${_CIDRs[0]}"

    # Remove hostname from DNS
    e_note "Removing container from DNS"

    # get a list of registered hostnames in DNS
    IFS=$'\n' local -a _registeredDNSNames=($( zfs_get_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.registered_dns_names"))
    local _dnsRecord
    local _exitCode=0
    for _dnsRecord in "${_registeredDNSNames[@]}"; do
        unbound_remove_records "${_dnsRecord}" "${uuid}" ""

        _exitCode=$(( ${_exitCode} & $? ))
    done

    if [[ ${_exitCode} -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi

    local _file

    # loop over upstream files, removing this ip address
    if [[ ${#_nginxUpstreamFiles[@]} -gt 0 ]]; then
        for _file in ${_nginxUpstreamFiles[@]}; do
            remove_lines_from_file "${_nginxUpstreamDir}/${_file}" "${_IP_ADDRESSES[0]}" "false"

            # flag nginx to be reloaded
            _reloadNginx="true"

            # check to see if the upstream file is now blank except for the block
            if [[ -z $( get_data_between_strings "upstream ${_file} {" "}" "$( cat "${_nginxUpstreamDir}/${_file}" 2> /dev/null )" ) ]]; then
                # delete the upstream file
                rm -f "${_nginxUpstreamDir}/${_file}"
            fi
        done
    fi

    local _url
    # loop over server name files
    if [[ ${#_nginxServerNameFiles[@]} -gt 0 ]]; then
        for _file in ${_nginxServerNameFiles[@]}; do
            if [[ -f "${_nginxServerNameDir}/${_file}" ]]; then
                # extract the domain name from this file
                local _domain=$( cat "${_nginxServerNameDir}/${_file}" | grep -F "server_name " | awk '{print $2}' )
                # trim the semicolon
                _domain=$( rtrim "${_domain}" ';' )

                # loop over the urls, looking for this domain name
                for _url in ${_urls[@]}; do
                    if [[ "${_url}" =~ ^${_domain}$ ]] || [[ "${_url}" =~ ^${_domain}/ ]]; then
                        # extract the directory part
                        if string_contains_char "${_url}" '/'; then
                            local _urlDirectory="/$(rcut ${_url} '/')"
                        else
                            local _urlDirectory='/'
                        fi

                        # get the contents of the block
                        local _locationBlock=$( get_data_between_strings "location ${_urlDirectory} {" "}" "$( cat "${_nginxServerNameDir}/${_file}" )" )

                        # check if there are other containers using this url
                        if [[ $( zfs get -r -H -o name,property,value all "${ZFS_TREDLY_PARTITIONS_DATASET}" | grep "${ZFS_PROP_ROOT}.url" | \
                            grep -v "${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${uuid}" | \
                            grep "${_url}" | wc -l ) -eq 0 ]]; then

                            # remove the block
                            delete_data_from_file_between_strings_inclusive "location ${_urlDirectory} {" "}" "${_nginxServerNameDir}/${_file}"
                        else
                            # other containers are using this url so remove any reference to this containers access file
                            remove_lines_from_file "${_nginxServerNameDir}/${_file}" "$( regex_escape "include ${_nginxAccessFileDir}/${uuid}")" "false"
                        fi

                        # flag nginx to be reloaded
                        _reloadNginx="true"
                        # if this file no longer contains location defs then delete it
                        if [[ $( cat "${_nginxServerNameDir}/${_file}" | grep 'location ' | grep -v 'location /tredly_error_docs ' | wc -l ) -eq 0 ]]; then
                            # no location defs, go ahead and delete the file
                            e_verbose "No location defs found, deleting ${serverNameFullpath}..."
                            rm -f "${_nginxServerNameDir}/${_file}"
                        fi
                    fi
                done

            fi
        done
    fi

    # now remove any redirect urls
    local _redirectUrl

    # loop over the redirect urls
    for _redirectUrl in ${_redirectUrls[@]}; do
        # remove the protocol
        local _redirectUrlTransformed=$( rcut "${_redirectUrl}" '://' )
        # extract the directory part
        if string_contains_char "${_redirectUrlTransformed}" '/'; then
            local _urlProtocol=$(lcut "${_redirectUrl}" '://' )
            local _urlDomain=$(lcut "${_redirectUrlTransformed}" '/' )
            local _urlDirectory="/$(rcut "${_redirectUrlTransformed}" '/')"
        else
            local _urlProtocol=$(lcut "${_redirectUrl}" '://' )
            local _urlDomain="${_redirectUrlTransformed}"
            local _urlDirectory='/'
        fi

        local _file=$( nginx_format_filename "${_urlProtocol}://${_urlDomain}" )

        # get the contents of the block
        local _locationBlock=$( get_data_between_strings "location ${_urlDirectory} {" "}" "$( cat "${_nginxServerNameDir}/${_file}" )" )

        # if it is a redirect block then check if the redirection for this is still necessary
        if [[ "${_locationBlock}" =~ 'return 301 http' ]]; then
            # extract the redirection
            local _redirectTo=$( echo "${_locationBlock}" | awk '{print $3}' | tr -d '\n')
            # get rid of the semicolon
            _redirectTo=$( rtrim "${_redirectTo}" ';' )
            # and any trailing slash
            _redirectTo=$( rtrim "${_redirectTo}" '/' )
            # format it into a filename
            local _redirectToFile=$( nginx_format_filename "${_redirectTo}" )
            _redirectToFile=$( lcut "${_redirectToFile}" '$' )

            # if the destination file doesnt exist then clean up this definition
            if [[ ! -f "${_nginxServerNameDir}/${_redirectToFile}" ]]; then
                # remove the block
                delete_data_from_file_between_strings_inclusive "location ${_urlDirectory} {" "}" "${_nginxServerNameDir}/${_file}"
            else
                # get the location block for the destination URL
                local _locationBlock=$( get_data_between_strings "location ${_urlDirectory} {" "}" "$( cat "${_nginxServerNameDir}/${_redirectToFile}" 2> /dev/null )" )

                # check if its blank
                if [[ -z "${_locationBlock}" ]]; then
                    # remove the block
                    delete_data_from_file_between_strings_inclusive "location ${_urlDirectory} {" "}" "${_nginxServerNameDir}/${_file}"
                fi
            fi
        fi

        # flag nginx to be reloaded
        _reloadNginx="true"

        # if this file no longer contains location defs then delete it
        if [[ $( cat "${_nginxServerNameDir}/${_file}" | grep 'location ' | grep -v 'location /tredly_error_docs ' | wc -l ) -eq 0 ]]; then
            # no location defs, go ahead and delete the file
            e_verbose "No location defs found, deleting ${serverNameFullpath}..."
            rm -f "${_nginxServerNameDir}/${_file}"
        fi

    done

    # Loop over this container's certs, checking if any other container is using them
    local _cert=''
    # combine the certificate arrays into a single array we can work with, and remove duplicates
    local -a _combinedCertList=(`for item in "${_urlCerts[@]}" "${_redirectUrlCerts[@]}" ; do echo "${item}" ; done | sort -du`)
    if [[ ${#_combinedCertList[@]} -gt 0 ]]; then
        e_note "Cleaning up SSL Certificates"

        local _exitCode=0
        for _cert in ${_combinedCertList[@]}; do
            # check if this cert is in use by containers in this partition
            local _urlCertInUse=$( zfs get -r -H -o value,property,name all ${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME} | grep "${ZFS_PROP_ROOT}.url_cert:" | grep -v "${uuid}\|cntr$" | grep "${_cert}" | wc -l )
            local _urlRedirectCertInUse=$( zfs get -r -H -o value,property,name all ${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME} | grep "${ZFS_PROP_ROOT}.redirect_url_cert:" | grep -v "${uuid}\|cntr$" | grep "${_cert}" | wc -l )

            # if nothing was found then delete the cert from nginx
            if [[ ${_urlCertInUse} -eq 0 ]] && [[ ${_urlRedirectCertInUse} -eq 0 ]]; then
                rm -f "${NGINX_SSL_DIR}/${_partitionName}/${_cert}/server.crt"
                _exitCode=$(( ${_exitCode} & $? ))
                rm -f "${NGINX_SSL_DIR}/${_partitionName}/${_cert}/server.key"
                _exitCode=$(( ${_exitCode} & $? ))
                rmdir "${NGINX_SSL_DIR}/${_partitionName}/${_cert}"
                _exitCode=$(( ${_exitCode} & $? ))
            fi
        done

        if [[ ${_exitCode} -eq 0 ]]; then
            e_success "Success"
        else
            e_error "Failed"
        fi
    fi

    # clean up the access file if it exists
    if [[ -f "${_nginxAccessFileDir}/$( nginx_format_filename "${uuid}" )" ]]; then
        rm -f "${_nginxAccessFileDir}/${uuid}"
        # flag nginx to be reloaded
        _reloadNginx="true"
    fi

    local _exitCode=0
    ## check to see if we need to update the proxy
    if [[ ${#_urls[@]} -gt 0 ]]; then
        e_note "Removing url registration from DNS"

        # loop over the urls, removing the urls associated with this container from DNS
        for _url in ${_urls[@]}; do
            # split up the url into its domain and directory segments
            # check if the url actually contained a /
            if string_contains_char "${_url}" '/'; then
                _urlDomain=$(lcut ${_url} '/')
            else
                _urlDomain="${_url}"
            fi
            # remove this container from DNS
            if unbound_remove_records "${_urlDomain}" "${uuid}"; then
                _exitCode=$(( ${_exitCode} & $? ))
                e_verbose "Removed record ${_urlDomain} from DNS"
            else
                _exitCode=$(( ${_exitCode} & $? ))
                e_error "Failed to remove ${_urlDomain} from DNS"
            fi
        done

        if [[ ${_exitCode} -eq 0 ]]; then
            e_success "Success"
        else
            e_error "Failed"
        fi
    fi

    # Remove any layer 4 proxy ports
    local _exitCode=0
    if [[ ${#_layer4ProxyTCP[@]} -gt 0 ]] || [[ ${#_layer4ProxyUDP[@]} -gt 0 ]] ; then
        e_note "Removing Layer 4 proxy (tcp/udp) rules for ${_containerName}"
        local _ip
        for _ip in "${_IP_ADDRESSES[@]}"; do
            e_verbose "Removing ${ip} from layer 4 proxy"
            remove_lines_from_file "${IPFW_FORWARDS}" "redirect_port tcp ${_ip}:"
            _exitCode=$(( ${_exitCode} & $? ))
            remove_lines_from_file "${IPFW_FORWARDS}" "redirect_port udp ${_ip}:"
            _exitCode=$(( ${_exitCode} & $? ))
        done

        # Run the layer 4 proxy script to update the ports
        sh "${IPFW_FORWARDS}"
        _exitCode=$(( ${_exitCode} & $? ))
        if [[ ${_exitCode} -eq 0 ]]; then
            e_success "Success"
        else
            e_error "Failed"
        fi
    fi

    # check if this is a public container
    if [[ "${_INTERFACES[0]}" == "${_CONF_COMMON[wif]}" ]]; then
        # remove the ip from the ipfw table
        ipfw table 1 delete ${_IP_ADDRESSES[0]} > /dev/null 2>&1
        # remove the epair from the ipfw table
        ipfw table 2 delete ${_hostIface} > /dev/null 2>&1
    fi

    # make sure the hosts epair exists before attempting to destroy it
    if  [[ "${_hostIface}" != '-' ]] && network_interface_exists "${_hostIface}"; then
        e_note "Removing container networking"

        # remove hosts epair
        ifconfig ${_hostIface} destroy
        if [[ $? -eq 0 ]]; then
            e_success "Success"
        else
            e_error "Failed"
        fi
    fi

    # do some cleanup if the container is started
    if [[ "${_containerStarted}" == "true" ]]; then
        local jid=$(find_jail_id "${uuid}")

        # check if the onstop script exists within the container, and run it if it does
        if [[ -f "${_containerMountPoint}/root${_onStopScript}" ]]; then
            e_note "Running onStop script"

            jexec trd-${uuid} sh -c "${_onStopScript}"

            if [[ $? -eq 0 ]]; then
                e_success "Success"
            else
                e_error "Failed"
            fi
        fi

        # Do workarounds for postgres
        local _postgresInstalled=$( pkg -j trd-${uuid} info | grep ".*postgresql[0-9]*-server.*" | wc -l )
        if [[ ${_postgresInstalled} -gt 0 ]]; then
            workaround_postgresql-server_stop "${jid}"
        fi

        # unmount any persistent storage
        if [[ "${_persistentStorageUUID}" != "-" ]]; then
            e_note "Detaching persistent storage from ${_containerName}"

            # get the mountpoint
            local _persistentMountPoint=$( ltrim "${_persistentMountPoint}" '/' )

            # detach it
            zfs_unmount_nullfs_in_jail "${_persistentMountPoint}"

            if [[ $? -eq 0 ]]; then
                e_success "Success"
            else
                e_error "Failed"
            fi
        fi

        e_note "Stopping container ${_containerName}"

        # container is started so stop it
        jail -r "trd-${uuid}"

        if [[ $? -eq 0 ]]; then
            e_success "Success"
        else
            e_error "Failed"
        fi
    fi

    e_note "Destroying container ${_containerName}"

    # destroy the container
    zfs_destroy_container "${_partitionName}" "${uuid}"
    if [[ $? -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi

    # tear down any resource limits if they were placed
    local _rctlLimitsApplied=$( rctl | grep "^jail:trd-${uuid}" | wc -l )

    if [[ ${_rctlLimitsApplied} -gt 0 ]]; then
        e_note "Removing resource limits"

        rctl -r "jail:trd-${uuid}"

        if [[ $? -eq 0 ]]; then
            e_success "Success"
        else
            e_error "Failed"
        fi
    fi

    # update the firewall rules for all containers within this container group if specified
    if [[ "${_containerGroupName}" != '-' ]] && [[ -n "${_containerGroupName}" ]]; then
        e_note "Updating container group firewall rules"
        ipfw_container_update_containergroup_members "${_containerGroupName}" "${_partitionName}"
        if [[ $? -eq 0 ]]; then
            e_success "Success"
        else
            e_error "Failed"
        fi
    fi

    # Reload DNS
    e_note "Reloading DNS server"
    if unbound_reload; then
        e_success "Success"
    else
        e_error "Failed"
    fi

    # reload nginx
    if [[ "${_reloadNginx}" == "true" ]]; then
        e_note "Reloading Layer 7 Proxy"
        if nginx_reload; then
            e_success "Success"
        else
            e_error "Failed"
        fi
    fi

    _endEpoch=$( date +%s )

    e_success "Destruction completed at `date -r ${_endEpoch} '+%d/%m/%Y %H:%M:%S %z'`"

    # if buildepoch isnt set then dont output the uptime
    if [[ -n "${_buildEpoch}" ]] && [[ "${_buildEpoch}" != '-' ]]; then
        # get the uptime of this container in seconds
        _uptimeEpoch=$(( ${_endEpoch} - ${_buildEpoch} ))
        _containerUptime=$( show_time ${_uptimeEpoch} )

        _scriptTime=$(( ${_endEpoch} - ${_startEpoch} ))

        e_success "Container uptime: ${_containerUptime}"
        e_success "Total time taken: ${_scriptTime} seconds"
    fi
}

# updates a container - create new one, then destroy old one
# new container containerName always comes from --path
# old container containerName comes from --uuid or --containerName or --path
function container_replace() {
    local _old_container_uuid _new_container_name _uuid _CONTAINER_CWD _header _old_container_exists

    local _partitionName="${1}"
    local input="${2}"

    # Pre flight checks

    if [[ -z "${_partitionName}" ]]; then
        exit_with_error "Please include a partition name."
    fi

    # work out whether this is a containerName or a uuid, and get the uuid if necessary
    if [[ -n "${input}" ]]; then
        if container_exists "${input}"; then
            _old_container_uuid="${input}"
        else
            e_verbose "containerName received, converting \"${input}\" to uuid"
            _old_container_uuid=$( get_uuid_from_container_name "${_partitionName}" "${input}" )

            if [[ -z "${_old_container_uuid}" ]]; then
                exit_with_error "Couldn't find specified container \"${input}\""
            fi
        fi
    fi

    # need to specify path
    if [[ -z "${_FLAGS[path]}" ]]; then
        exit_with_error "Please specify the path of the new container with --path="
    fi

    # end pre flight checks

    _CONTAINER_CWD="$(rtrim ${_FLAGS[path]} /)/"

    # set the tredlyfile
    tredlyFile="$( rtrim ${_CONTAINER_CWD} '/' )/Tredlyfile"

    # Parse the tredlyfile, and exit with an error if it doesnt exist
    if ! tredlyfile_parse "${tredlyFile}"; then
        exit_with_error "Failed to locate Tredlyfile or it was invalid at ${_CONTAINER_CWD}"
    fi

    local _old_container_dataset

    # get the container names
    _new_container_name="${_CONF_TREDLYFILE[containerName]}"

    # if the old uuid is not set then we need to find it
    if [[ -z "${_old_container_uuid}" ]]; then

        # find the uuid of the container
        _old_container_name="${_new_container_name}"
        _old_container_uuid=$( get_uuid_from_container_name "${_partitionName}" "${_old_container_name}" )

        # set the dataset for the old container
        _old_container_dataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${_old_container_uuid}"

    else
         # set the dataset for the old container
         _old_container_dataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${_old_container_uuid}"
         _old_container_name=$( zfs_get_property "${_old_container_dataset}" "${ZFS_PROP_ROOT}:containername" )
    fi

    # end sanity checks
    if ! container_exists "${_old_container_uuid}"; then
        e_header "Replacing Container ${_old_container_name}"
        e_note "Container to replace does not exist"
    else
        # rename the old container
        e_header "Replacing Container ${_old_container_name} with ${_new_container_name}"
        if ! zfs_set_property "${_old_container_dataset}" "${ZFS_PROP_ROOT}:containername" "${_old_container_name}-OLD"; then
            e_error "Failed to rename old container"
        fi
    fi

    # create the container
    container_create "true" "${_partitionName}"

    # destroy the container if one already exists
    if container_exists "${_old_container_uuid}"; then
        destroy_container "${_old_container_uuid}" "${_partitionName}"
    fi
}
