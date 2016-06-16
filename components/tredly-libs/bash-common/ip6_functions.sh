#!/usr/bin/env bash

# params: startaddress, cidr
function ip6_find_available_address() {
    #local network="2001:470:26:307"
    local _network="fd76:6df6:8457:1553"
    local _array=( 1 2 3 4 5 6 7 8 9 0 a b c d e f )

    echo "${_network}:${_array[$RANDOM%16]}${_array[$RANDOM%16]}${_array[$RANDOM%16]}${_array[$RANDOM%16]}:${_array[$RANDOM%16]}${_array[$RANDOM%16]}${_array[$RANDOM%16]}${_array[$RANDOM%16]}:${_array[$RANDOM%16]}${_array[$RANDOM%16]}${_array[$RANDOM%16]}${_array[$RANDOM%16]}:${_array[$RANDOM%16]}${_array[$RANDOM%16]}${_array[$RANDOM%16]}${_array[$RANDOM%16]}"
}


function ip6_get_container_interface_ip() {
    local _uuid="${1}"
    local _iface="${2}"

    local _output=$( jexec trd-${_uuid} ifconfig ${interface} | awk 'sub(/inet6 /,""){print $1}' )

    local _retVal=$?
    echo "${_output}"
    return ${_retVal}
}
