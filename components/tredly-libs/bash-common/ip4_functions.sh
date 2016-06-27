#!/usr/bin/env bash

# checks where an ip address is RFC 1918 private or not
# https://en.wikipedia.org/wiki/Private_network#Private_IPv4_address_spaces
function is_private_ip4() {
    local _checkIP="${1}"

    # explode the ip into its elements
    IFS=. read -r i1 i2 i3 i4 <<< "${_checkIP}"

    # check for private ranges
    if [[ i1 -eq 10 ]]; then
        return ${E_SUCCESS}
    elif [[ i1 -eq 172 ]]; then
        if [[ i2 -ge 16 ]] && [[ i2 -le 31 ]]; then
            return ${E_SUCCESS}
        fi
    elif [[ i1 -eq 192 ]] && [[ i2 -eq 168 ]]; then
        return ${E_SUCCESS}
    fi
    return ${E_ERROR}
}

# randomly generates a port number and checks to see if it is in use
# there is no reason why this cant simply start at minPort and increment
# params: protocol, ipaddress
function find_available_port() {
    local protocol="${1}"
    local ipAddr="${2}"
    local _minPort="${3}"
    local _maxPort="${4}"

    local newPort=""

    while [[ -z "$newPort" ]]; do
        # get a random number between our given ranges
        local randomPort=$( jot -r 1 ${_minPort} ${_maxPort} )

        # check to see if its in use
        local output=$( sockstat -4 | grep -F " ${ipAddr}:${randomPort} "  | grep -F " ${protocol}4 " | wc -l )

        # its not in use so assign this port
        if [[ "$output" -eq 0 ]]; then
            newPort="${randomPort}"
        fi
    done

    if [[ -n "${newPort}" ]]; then
        echo "${newPort}"
        return ${E_SUCCESS}
    fi

    echo ''
    return ${E_FATAL}
}

# finds an available ip address within the given network
# params: startaddress, cidr
function find_available_ip_address() {
    local network="${1}"
    local cidr="${2}"

    local newIP=""
    local nextaddr=""

    # get the next ip, check to see if its in use
    while [[ -z "$newIP" ]]; do
        nextaddr=$( get_ip4_random_address "${network}" "${cidr}" )

        if [[ $? -eq ${E_FATAL} ]]; then
            exit_with_error "IP address pool exhausted!"
        fi

        # check if its in use
        #output=$( ifconfig | grep -F " ${nextaddr} " | wc -l )
        local output=$( zfs get -H -o property,value -r ${ZFS_PROP_ROOT}:ip4_addr ${ZFS_TREDLY_PARTITIONS_DATASET} | grep -F "|${nextaddr}/" | wc -l )

        if [[ "${output}" -eq 0 ]]; then
            newIP="${nextaddr}"
        fi

    done

    echo "$newIP"
    return ${E_SUCCESS}
}

## Uses ifconfig and to obtain the ip address(es) for a given network interface
##
## Arguments:
##     1. String. Network interface name
##
## Usage:
##
##
## Return:
##     array
function get_interface_ip4() {
    local interface="${1}"

    local output=$( ifconfig ${interface} | awk 'sub(/inet /,""){print $1}' )

    local retVal=$?
    echo "${output}"
    return ${retVal}
}

# gets the ip address of a container's interface
function get_container_interface_ip4() {
    local _uuid="${1}"
    local _iface="${2}"

    local _output=$( jexec trd-${_uuid} ifconfig ${interface} | awk 'sub(/inet /,""){print $1}' )

    local _retVal=$?
    echo "${_output}"
    return ${_retVal}
}

## Uses ifconfig and grep to look for the network interface
## specified in the first argment.
##
## Arguments:
##     1. String. Network interface name
##
## Usage:
##     if network_interface_exists "lo1"; then echo good; else echo bad; fi
##
## Return:
##     bool
function network_interface_exists() {
    local _interfaceName="${1}"

    if [[ -z $(ifconfig | grep "^${_interfaceName}:") ]]; then
        return ${E_ERROR}
    fi

    return ${E_SUCCESS}
}

# given an ip4 address, return the next in the sequence
function get_ip4_next_address() {
    local ip4="${1}"
    # convert the cidr into a netmask
    local netmask=$( cidr2netmask "${2}" )
    local broadcast=$( get_ip4_broadcast_address "${ip4}" "${2}" )

    local m1 m2 m3 m4
    local o1 o2 o3 o4

    IFS=. read -r o1 o2 o3 o4 <<< "${ip4}"
    IFS=. read -r m1 m2 m3 m4 <<< "${netmask}"

    # increment the last octet
    o4=$(( $o4 + 1  ))

    # attempt to get the next ip address
    if [[ "$o4" -gt 255 ]]; then
        o4=0
        o3=$(( $o3 + 1 ))

        if [[ "$o3" -gt 255 ]]; then
            o3=0
            o2=$(( $o2 + 1 ))

            if [[ "$o2" -gt 255 ]]; then
                o2=0
                o1=$(( $o1 + 1 ))

                if [[ "$o1" -gt 255 ]]; then
                    echo ""
                    return ${E_FATAL}
                fi
            fi
        fi
    fi

    newIP=$(printf "%d.%d.%d.%d" "${o1}" "${o2}" "${o3}" "${o4}")

    # make sure we're not going to output the broadcast address
    if [[ "${newIP}" != "${broadcast}" ]]; then
        echo "$newIP"
        return ${E_SUCCESS}
    fi

    echo ""
    return ${E_FATAL}
}

# given an ip4, finds the last usable ip4 address in the network
function get_last_usable_ip4_in_network() {
    local ip4="${1}"

    # convert the cidr into a netmask
    local broadcast=$( get_ip4_broadcast_address "${ip4}" "${2}" )

    local b1 b2 b3 b4

    IFS=. read -r b1 b2 b3 b4 <<< "${broadcast}"

    # decrement the last octet
    b4=$(( b4 - 1 ))

    printf "%d.%d.%d.%d" "${b1}" "${b2}" "${b3}" "${b4}"
    return ${E_SUCCESS}
}

# Returns a random address from a given network and cidr
function get_ip4_random_address() {
    local network="${1}"
    # convert the cidr into a netmask
    local cidr="${2}"
    local netmask=$( cidr2netmask "${cidr}" )
    local broadcast=$( get_ip4_broadcast_address "${network}" "${2}" )

    if [[ ${cidr} -eq 32 ]]; then
        echo "${network}"
        return ${E_SUCCESS}
    fi

    local n1 n2 n3 n4
    local b1 b2 b3 b4
    local r1 r2 r3 r4

    IFS=. read -r n1 n2 n3 n4 <<< "${network}"
    IFS=. read -r b1 b2 b3 b4 <<< "${broadcast}"

    # increment/decrement the last octet as this is the network or broadcast addres
    if [[ ${n4} -lt 255 ]]; then
        n4=$(( n4 + 1 ))
    fi

    if [[ ${b4} -gt 0 ]]; then
        b4=$(( b4 - 1 ))
    fi

    #randomise each octet between network and broadcast addresses
    local r1=$( jot -r 1 ${n1} ${b1} )
    local r2=$( jot -r 1 ${n2} ${b2} )
    local r3=$( jot -r 1 ${n3} ${b3} )
    local r4=$( jot -r 1 ${n4} ${b4} )

    newIP=$(printf "%d.%d.%d.%d" "${r1}" "${r2}" "${r3}" "${r4}")

    # make sure we're not going to output the broadcast address or network address
    if [[ "${newIP}" != "${broadcast}" ]] && [[ "${newIP}" != "${network}" ]]; then
        echo "$newIP"
        return ${E_SUCCESS}
    fi

    echo ""
    return ${E_FATAL}
}

# Converts a netmask to a cidr
function netmask2cidr() {
   # Assumes there's no "255." after a non-255 byte in the mask
   local x=${1##*255.}
   set -- 0^^^128^192^224^240^248^252^254^ $(( (${#1} - ${#x})*2 )) ${x%%.*}
   x=${1%%$3*}
   echo $(( $2 + (${#x}/4) ))
   return ${E_SUCCESS}
}

# takes a cidr (in the form of 16,24,32 etc) and outputs its equivalent netmask
function cidr2netmask() {
    local i mask=""
    local full_octets=$(($1/8))
    local partial_octet=$(($1%8))

    for ((i=0;i<4;i+=1)); do
        if [ $i -lt $full_octets ]; then
            mask+=255
        elif [ $i -eq $full_octets ]; then
            mask+=$((256 - 2**(8-$partial_octet)))
        else
            mask+=0
        fi
        test $i -lt 3 && mask+=.
    done

    echo $mask
    return $E_SUCCESS
}

# takes 2 args - 1st is the ip4_addr. ie <iface>|<ip4addr>/<cidr>
# 2nd is a string. eg "ip4, cidr, or interface". defaults to ip4
function extractFromIP4Addr() {
    local _ip4_addr="${1}"
    local _toExtract="${2}"
    # split it
    [[ ${_ip4_addr} =~ ^([^|]+)\|(.+)/(.+)$ ]]
    local -a re
    re=("${BASH_REMATCH[@]}")
    case "${_toExtract}" in
        interface)
            echo "${re[1]}"
            ;;
        cidr|netmask)
            echo "${re[3]}"
            ;;
        *)  # aka ip4
            echo "${re[2]}"
            ;;
    esac
    return $E_SUCCESS
}

# takes an ip address, and checks if it is valid or not
function is_valid_ip4() {
    # extract the ip4 address in case we were passed a netmask or cidr
    local _ip4=$( lcut "${1}" '/' )

    # make sure the string contains 3 dots
    local numDots=$( grep -o -F '.' <<< "${_ip4}" | wc -l)
    if [[ ${numDots} -ne 3 ]]; then
        return $E_ERROR
    fi

    # explode the ip into its elements and loop over them
    local IFS='.'
    for value in ${_ip4}
    do
        # if this value is < 0 or > 255 then its bogus
        if [[ "${value}" -lt "0" || "${value}" -gt "255" || ! "${value}" =~ ^[0-9]{1,3}$ ]]; then
            return ${E_ERROR}
        fi
    done

    return ${E_SUCCESS}
}

# takes an ip address, and checks if it is valid or not
function is_valid_cidr() {
    if ! is_int "${1}"; then
        return ${E_ERROR}
    fi
    
    if [[ "${1}" -lt "0" ]] || [[ "${1}" -gt "32" ]]; then
        return ${E_ERROR}
    fi

    return ${E_SUCCESS}
}

# Given an ip address and netmask, calculate the network address
# eg: ip4     = 192.168.0.240
#     netmask = 255.255.255.0
# networkaddr = 192.168.0.0
function get_ip4_network_address() {
    local ip4="${1}"
    # convert the cidr into a netmask
    local netmask=$( cidr2netmask "${2}" )

    local i1 i2 i3 i4
    local m1 m2 m3 m4

    IFS=. read -r i1 i2 i3 i4 <<< "${ip4}"
    IFS=. read -r m1 m2 m3 m4 <<< "${netmask}"

    printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$((i4 & m4))"
}

# Given an ip address and netmask, calculate the broadcast address
# eg: ip4       = 192.168.0.240
#     netmask   = 255.255.255.0
# broadcastaddr = 192.168.0.255
function get_ip4_broadcast_address() {
    local ip4="${1}"
    # convert the cidr into a netmask
    local netmask=$( cidr2netmask "${2}" )

    local i1 i2 i3 i4
    local m1 m2 m3 m4

    IFS=. read -r i1 i2 i3 i4 <<< "${ip4}"
    IFS=. read -r m1 m2 m3 m4 <<< "${netmask}"

    # wildcard it
    m1=$((255 - m1))
    m2=$((255 - m2))
    m3=$((255 - m3))
    m4=$((255 - m4))

    printf "%d.%d.%d.%d\n" "$((i1 | m1))" "$((i2 | m2))" "$((i3 | m3))" "$((i4 | m4))"
}

# takes an ip4 address and a network address (including cidr) and checks to see if that ip4 address falls within the given network
function ip4_is_network_member() {
    local _ip4="${1}"
    local _network="${2}"

    # split out the network and cidr
    local _network _cidr
    IFS=/ read -r _network _cidr <<< "${_network}"

    local _broadcast=$( get_ip4_broadcast_address "${_network}" "${_cidr}" )

    # separate the ip addresses into their octets
    IFS=. read -r i1 i2 i3 i4 <<< "${_ip4}"
    IFS=. read -r n1 n2 n3 n4 <<< "${_network}"
    IFS=. read -r b1 b2 b3 b4 <<< "${_broadcast}"

    # check each octet
    if [[ i1 -ge n1 ]] && [[ i1 -le b1 ]]; then
        # 2nd octet
        if [[ i2 -ge n2 ]] && [[ i2 -le b2 ]]; then
            # 3rd octet
            if [[ i3 -ge n3 ]] && [[ i3 -le b3 ]]; then
                # 4th octet
                if [[ i4 -ge n4 ]] && [[ i4 -le b4 ]]; then
                    return ${E_SUCCESS}
                fi
            fi
        fi
    fi

    return ${E_ERROR}
}
# generates a random mac address
function generate_mac_address() {
    local RANGE=255

    # generate random numbers
    local number=$RANDOM
    local numbera=$RANDOM
    local numberb=$RANDOM

    # ensure they are less than ceiling
    let "number %= $RANGE"
    let "numbera %= $RANGE"
    let "numberb %= $RANGE"

    # set mac stem
    local octets="02:33:11"

    # use bc to change int to hex
    local octeta=$( echo "obase=16;$number" | bc )
    local octetb=$( echo "obase=16;$numbera" | bc )
    local octetc=$( echo "obase=16;$numberb" | bc )

    echo "${octets}:${octeta}:${octetb}:${octetc}"
}

# changes the hosts network details
function ip4_set_host_network() {
    local _interface="${1}"
    local _ip4Arg="${2}"

    local _ip4CIDR=$( rcut "${_ip4Arg}" '/' )
    local _ip4=$( lcut "${_ip4Arg}" '/' )

    local _exitCode=0
    
    e_header "Setting Tredly host IP address to ${_ip4} on interface ${_interface}"
    

    if [[ -z "${_ip4}" ]]; then
        exit_with_error "Please include an ip address"
    fi

    if ! is_valid_ip4 "${_ip4}"; then
        exit_with_error "${_ip4} is not a valid IP address"
    fi
    if ! is_valid_cidr "${_ip4CIDR}"; then
        exit_with_error "${_ip4CIDR} is not a valid CIDR"
    fi
    
    # make sure the interface exists
    if ! network_interface_exists "${_interface}"; then
        exit_with_error "Interface ${_interface} does not exist"
    fi

    # make sure the new ip address doesnt fall within the container subnet
    if [[ -n "${_CONF_COMMON[lifNetwork]}" ]]; then
        if ip4_is_network_member "${_ip4}" "${_CONF_COMMON[lifNetwork]}/${_CONF_COMMON[lifCIDR]}"; then
            exit_with_error "IP ${_ip4} falls within your container subnet. If you wish to use this ip address, please change your container subnet"
        fi
    fi

    local _ip4Subnet=$( cidr2netmask "${_ip4CIDR}" )

    # set the ip address
    local _exitCode=0
    e_note "Changing IP Address on interface ${_interface}"
    
    ifconfig ${_interface} inet ${_ip4} netmask ${_ip4Subnet}
    _exitCode=$(( ${_exitCode} & $? ))

    # set the ip in the table
    ipfw_add_persistent_table_member "" "5" "${_ip4}"
    _exitCode=$(( ${_exitCode} & $? ))
    
    # and the interface
    ipfw_add_persistent_table_member "" "6" "${_interface}"
    _exitCode=$(( ${_exitCode} & $? ))
    
    if [[ ${_exitCode} -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi
    
    # check if a line for this interface exists within rc.conf
    local _numLines=$( cat "/etc/rc.conf" | grep "^ifconfig_${_interface}=" | wc -l )

    local _lineToAdd="ifconfig_${_interface}=\"inet ${_ip4} netmask ${_ip4Subnet}\""

    e_note "Updating rc.conf"
    if [[ ${_numLines} -gt 0 ]]; then
        # line exists, change the network information in rc.conf
        sed -i '' "s|ifconfig_${_interface}=.*|${_lineToAdd}|g" "/etc/rc.conf"
        _exitCode=$?
    else
        # does not exist, echo it in
        echo "${_lineToAdd}" >> "/etc/rc.conf"
        _exitCode=$?
    fi
    if [[ ${_exitCode} -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi

    e_note "Updating SSHD"
    # change the listen address for ssh
    sed -i '' "s|ListenAddress .*|ListenAddress ${_ip4}|g" "/etc/ssh/sshd_config"
    _exitCode=$?
    if [[ $? -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi

    e_note "Updating IPFW"
    local _exitCode=0
    # change the external ip for IPFW
    ipfw_add_persistent_table_member "" 5 "${_ip4}"
    _exitCode=$(( ${_exitCode} & $? ))
    
    # update ipfw.vars
    replace_line_in_file "^eip=\".*\"" "eip=\"${_ip4}\"" "/usr/local/etc/ipfw.vars"
    _exitCode=$(( ${_exitCode} & $? ))
    
    # change the external interface for IPFW
    ipfw_add_persistent_table_member "" 6 "${_interface}"
    _exitCode=$(( ${_exitCode} & $? ))
    
    # update ipfw.vars
    replace_line_in_file "^eif=\".*\"" "eif=\"${_interface}\"" "/usr/local/etc/ipfw.vars"
    _exitCode=$(( ${_exitCode} & $? ))
    
    if [[ ${_exitCode} -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi

    e_note "Updating Tredly config"
    sed -i '' "s|wifPhysical=.*|wifPhysical=${_interface}|g" "${_TREDLY_DIR_CONF}/tredly-host.conf"
    _exitCode=$(( ${_exitCode} & $? ))
    if [[ ${_exitCode} -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi
    
    return ${_exitCode}
}

# changes the hosts gateway details
function ip4_set_host_gateway() {
    local _gateway="${1}"

    local _exitCode=0
    
    e_header "Setting Tredly host default gateway to ${_gateway}"

    # ensure its a valid ip4 address
    if ! is_valid_ip4 "${_gateway}"; then
        exit_with_error "Invalid IP4 address: ${_gateway}"
    fi

    # get the current default gateway
    local _currentGW=$( netstat -r | grep default | awk '{print $2}' )

    # try to set the default route
    route delete default > /dev/null 2>&1
    route add default ${_gateway} > /dev/null 2>&1

    # check if route errored and if it did, dont continue
    if [[ $? -ne 0 ]]; then
        # set the default back to the original
        route delete default > /dev/null 2>&1
        route add default ${_currentGW} > /dev/null 2>&1
        exit_with_error "Failed to set default gateway to ${_gateway}. Is the network reachable from your Tredly host?"
    fi

    local _lineToAdd="defaultrouter=\"${_gateway}\""

    # check if the line already exists
    local _numLines=$( cat "/etc/rc.conf" | grep "^defaultrouter=" | wc -l )

    if [[ ${_numLines} -gt 0 ]]; then
        # change rc.conf
        sed -i '' "s|defaultrouter=.*|${_lineToAdd}|g" "/etc/rc.conf"
        _exitCode=$(( ${_exitCode} & $? ))
    else
        # add it
        echo "${_lineToAdd}" >> "/etc/rc.conf"
        _exitCode=$(( ${_exitCode} & $? ))
    fi

    if [[ ${_exitCode} -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi

    return ${_exitCode}
}

# changes the hosts hostname
function ip4_set_host_hostname() {
    local _hostname="${1}"
    local _exitCode=0
    
    e_header "Setting Tredly hostname to ${_hostname}"

    # ensure a hostname was received
    if [[ -z "${_hostname}" ]]; then
        exit_with_error "Please enter a hostname"
    fi

    # change the live hostname
    hostname "${_hostname}"
    _exitCode=$(( ${_exitCode} & $? ))

    local _lineToAdd="hostname=\"${_hostname}\""

    # check if the line already exists
    local _numLines=$( cat "/etc/rc.conf" | grep "^hostname=" | wc -l )

    if [[ ${_numLines} -gt 0 ]]; then
        # make it permanent across reboots
        sed -i '' "s|hostname=.*|${_lineToAdd}|g" "/etc/rc.conf"
        _exitCode=$(( ${_exitCode} & $? ))
    else
        echo "${_lineToAdd}" >> "/etc/rc.conf"
        _exitCode=$(( ${_exitCode} & $? ))
    fi
    

    if [[ ${_exitCode} -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi
    return ${_exitCode}
}

# updates all configurations with the given new subnet for containers
function ip4_set_container_subnet() {
    local _ipSubnet="${1}"

    e_header "Setting container subnet to ${_ipSubnet}"

    # check if there are built containers
    local _containerCount=$( zfs_get_all_containers | wc -l )

    if [[ ${_containerCount} -gt 0 ]]; then
        exit_with_error "This host currently has built containers. Please destroy them and run this command again."
    fi

    # make sure we received a subnet mask/cidr
    if ! string_contains_char "${_ipSubnet}" "/"; then
        exit_with_error "Please include a subnet mask/cidr"
    fi

    # extract the ip4 address
    local _ip4=$( lcut "${1}" '/' )
    # and cidr
    local _cidr=$( rcut "${1}" '/' )

    if ! is_valid_cidr "${_cidr}"; then
        exit_with_error "Please include a valid cidr."
    fi

    # validate the arguments
    if ! is_valid_ip4 "${_ip4}"; then
        exit_with_error "${_ip4} is not a valid ip"
    fi
    if ! is_valid_cidr "${_cidr}"; then
        exit_with_error "${_cidr} is not a valid CIDR"
    fi

    # get the netmask for use later
    local _netMask=$( cidr2netmask "${_cidr}" )

    local _interface="${_CONF_COMMON[lif]}"
    
    local _oldJIP=''
    # get the old container ip so we can replace it
    if network_interface_exists "${_interface}"; then
        _oldJIP=$( get_interface_ip4 "${_interface}" )
    fi

    #################
    ## UPDATE HOSTS CONFIGS - rc.conf, ipfw.vars, tredly-host.conf
    #################
    # get the new ip address for the container interface
    local _newJIP=$( get_last_usable_ip4_in_network "${_ip4}" "${_cidr}" )

    local _exitcode=0

    # check if the local container interface exists
    if ! network_interface_exists "${_interface}"; then
        # check if vimage installed
        if [[ $( sysctl kern.conftxt | grep '^options[[:space:]]VIMAGE$' | wc -l ) -gt 0 ]]; then
            e_error "${_interface} does not exist."
        fi
    else
        # update the local container interface
        e_note "Updating interface ${_interface}"
        # remove the old jip
        ifconfig ${_interface} delete ${_oldJIP}
        _exitCode=$(( _exitCode & $? ))
        # add the new one
        ifconfig ${_interface} inet ${_newJIP} netmask ${_netMask}
        _exitCode=$(( _exitCode & $? ))
        # add this data to the persistent table
        ipfw_add_persistent_table_member "" "10" "${_ipSubnet}"
        _exitCode=$(( _exitCode & $? ))
        ipfw_add_persistent_table_member "" "11" "${_interface}"
        _exitCode=$(( _exitCode & $? ))
        ipfw_add_persistent_table_member "" "7" "${_newJIP}"
        _exitCode=$(( _exitCode & $? ))
        
        if [[ ${_exitCode} -eq 0 ]]; then
            e_success "Success"
        else
            e_error "Failed"
        fi
    fi
    
    e_note "Setting static IPs"
    local _layer7ProxyContainerIP=$( subtractFromBroadcast "${_ip4}/${_cidr}" "2" )
    local _tredlyCommandCenterContainerIP=$( subtractFromBroadcast "${_ip4}/${_cidr}" "3" )
    local _dnsContainer=$( subtractFromBroadcast "${_ip4}/${_cidr}" "4" )
    {
        echo "tredlyLayer7Proxy=${_layer7ProxyContainerIP}/${_cidr}"
        echo "tredlyDNS=${_tredlyCommandCenterContainerIP}/${_cidr}"
        echo "tredlyCC=${_dnsContainer}/${_cidr}"
    } > /usr/local/etc/tredly/static-ips.conf
    
    if [[ $? -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi

    e_note "Updating rc.conf"
    if replace_line_in_file "^ifconfig_${_interface}=\".*\"$" "ifconfig_${_interface}=\"inet ${_newJIP} netmask ${_netMask}\"" "/etc/rc.conf"; then
        e_success "Success"
    else
        e_error "Failed"
    fi

    e_note "Updating IPFW"
    local _exitCode=0
    
    # add tables
    ipfw_add_persistent_table_member "" 7 "${_newJIP}"
    _exitCode=$(( _exitCode & $? ))
    
    ipfw_add_persistent_table_member "" 10 "${_ip4}/${_cidr}"
    _exitCode=$(( _exitCode & $? ))
    
    ipfw_add_persistent_table_member "" 11 "${_interface}"
    _exitCode=$(( _exitCode & $? ))
    
    ipfw_add_persistent_table_member "" 20 "${_tredlyCommandCenterContainerIP}"
    _exitCode=$(( _exitCode & $? ))
    
    replace_line_in_file "^p7ip=\".*\"" "p7ip=\"${_newJIP}\"" "/usr/local/etc/ipfw.vars"
    _exitCode=$(( _exitCode & $? ))

    if [[ ${_exitCode} -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi

    # update tredly-host.conf
    e_note "Updating tredly-host.conf"
    if  replace_line_in_file "^lifNetwork=.*$" "lifNetwork=${_ip4}/${_cidr}" "${_TREDLY_DIR_CONF}/tredly-host.conf" && \
        replace_line_in_file "^dns=.*$" "dns=${_newJIP}" "${_TREDLY_DIR_CONF}/tredly-host.conf" && \
        replace_line_in_file "^httpproxy=.*$" "httpproxy=${_newJIP}" "${_TREDLY_DIR_CONF}/tredly-host.conf" && \
        replace_line_in_file "^vnetdefaultroute=.*$" "vnetdefaultroute=${_newJIP}" "${_TREDLY_DIR_CONF}/tredly-host.conf"; then

        e_success "Success"
    else
        e_error "Failed"
    fi

    e_note "Updating unbound.conf"
    sed -i '' "s|access-control: 10.0.0.0/16 allow|access-control: ${_ipSubnet} allow|g" "/usr/local/etc/unbound/unbound.conf"

    if  replace_line_in_file "^    interface: .*$" "    interface: ${_newJIP}" "/usr/local/etc/unbound/unbound.conf" && \
        replace_line_in_file "^    access-control: .* allow$" "    access-control: ${_ip4}/${_cidr} allow" "/usr/local/etc/unbound/unbound.conf"; then
        e_success "Success"
    else
        e_error "Failed"
    fi

    # check if unbound is running
    service unbound status > /dev/null 2>&1

    if [[ $? -eq 0 ]]; then
        # unbound running so reload it
        e_note "Reloading DNS server"
        service unbound reload
        if [[ $? -eq 0 ]]; then
            e_success "Success"
        else
            e_error "Failed"
        fi
    fi

    # check if ipfw module is loaded
    if [[ $( kldstat | grep 'ipfw.ko$' | wc -l ) -ne 0 ]]; then
        # module loaded so show message
        e_note "Firewall requires restart. Please run \"service ipfw restart\" when you are ready. Please note this may disconnect your ssh session"
    fi
}

# gets a list of interfaces which could possibly be external interfaces
function get_external_interfaces() {
    ifconfig | grep "^[a-zA-Z].*[0-9].*:" | grep -v "^lo0:" | grep -v "^bridge[0-9].*:" | awk '{ print $1 }' | tr -d :
}

# returns an interface's netmask
function get_interface_netmask() {
    local hexMask=$( ifconfig ${1} | grep 'inet ' | awk '{ print $4 }' | cut -d 'x' -f 2 )

    local netmask=$(( 16#${hexMask:0:2} )).$(( 16#${hexMask:2:2} )).$(( 16#${hexMask:4:2} )).$(( 16#${hexMask:6:2} ))

    echo "${netmask}"
}

# returns an interface's CIDR
function get_interface_cidr() {
    local _netmask=$( get_interface_netmask "${1}" )
    
    echo "$( netmask2cidr "${_netmask}" )"
}

# returns the default gateway on this host
function get_default_gateway() {
    netstat -r4n | grep '^default' | awk '{ print $2 }'
}

function is_valid_ip_or_range() {
    local _input="${1}"
    local _ip _cidr

    # check if it includes a cidr
    if string_contains_char "${_input}" "/"; then
        # split the ip out from cidr
        _ip=$( lcut "${_input}" '/' )
        _cidr=$( rcut "${_input}" '/' )
    else
        _ip="${_input}"
        _cidr=""
    fi
    
    # validate the ip
    if ! is_valid_ip4 "${_ip}"; then
        return ${E_ERROR}
    fi
    
    # validate the cidr if there was one
    if [[ -n "${_cidr}" ]]; then
        if ! is_valid_cidr "${_cidr}"; then
            return ${E_ERROR}
        fi
    fi

    return ${E_SUCCESS}
}


# returns the ip address for the given interface
function getInterfaceIP() {
    ifconfig ${1} | grep 'inet ' | awk '{ print $2 }'
}

# returns an interface's netmask
function getInterfaceNetmask() {
    local hexMask=$( ifconfig ${1} | grep 'inet ' | awk '{ print $4 }' | cut -d 'x' -f 2 )

    local netmask=$(( 16#${hexMask:0:2} )).$(( 16#${hexMask:2:2} )).$(( 16#${hexMask:4:2} )).$(( 16#${hexMask:6:2} ))

    echo "${netmask}"
}

# returns an interface's CIDR
function getInterfaceCIDR() {
    local _netmask=$( getInterfaceNetmask "${1}" )
    
    echo "$( netmask2cidr "${_netmask}" )"
}

# returns the default gateway on this host
function getDefaultGateway() {
    netstat -r4n | grep '^default' | awk '{ print $2 }'
}

# gets a list of interfaces which could possibly be external interfaces
function getExternalInterfaces() {
    ifconfig | grep "^[a-zA-Z].*[0-9].*:" | grep -v "^lo0:" | grep -v "^bridge[0-9].*:" | awk '{ print $1 }' | tr -d :
}


function is_valid_hostname() {
    local _hostname="${1}"
    # make sure length isnt > 255 chars
    if [[ ${#_hostname} -gt 255 ]]; then
        return ${E_ERROR}
    # match a valid hostname
    elif [[ "${_hostname}" =~ ^([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])(\.([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]))*$ ]]; then
        return ${E_SUCCESS}
    fi
    
    return ${E_ERROR}
}

# use python to do IP address math
function subtractFromBroadcast() {
    local _subnet="${1}"
    local _numToSubtract="${2}"

    # use python to subtract from the subnet
    /usr/local/bin/python3.5 - <<END
import ipaddress
# create an interface object
interface = ipaddress.IPv4Interface('${_subnet}')
# get a network object
network = interface.network
# get its broadcast
broadcast = network.broadcast_address
    
print(broadcast - ${_numToSubtract})
END
}