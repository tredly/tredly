#!/usr/bin/env bash

# prints out a nicely formatted menu for the user to configure their system
function tredlyHostMenuConfig() {
    
    local _userSelection _userChange
    
    # for our loop
    continue="true"
    
    while [[ "${continue}" == "true" ]]; do
        echo -en "${_colourMagenta}"
        echo -e "========================================================================================================================================="
        echo -e "The current defaults below will be used to install your Tredly Host. If you wish to change any options, please enter the relevant number:"
        echo -e "========================================================================================================================================="
        echo -en "${_colourDefault}"
        
        echo -en "${_colourOrange}"
        {
            echo -e "1.^External Interface^${_configOptions[1]}"
            echo -e "2.^External IP Address (including CIDR)^${_configOptions[2]}"
            echo -e "3.^External Gateway^${_configOptions[3]}"
            echo -e "4.^Hostname^${_configOptions[4]}"
            echo -e "5.^Container Subnet^${_configOptions[5]}"
            echo -e "6.^API Whitelist^${_configOptions[6]}"
            
        } | column -ts ^
        echo -en "${_colourDefault}"
        read -p "Which would you like to change? (or enter to continue) " _userSelection
        
        # stop the loop
        if [[ -z "${_userSelection}" ]]; then
            continue="false"
        else
            # validate user input
            case ${_userSelection} in
                1)
                    # external interface
                    tredlySelectExternalInterface
                ;;
                2)
                    # external ip address incl cidr
                    tredlySelectExternalIP
                ;;
                3)
                    # external gateway
                    tredlySelectExternalGateway
                ;;
                4)
                    # hostname
                    tredlySelectHostname
                ;;
                5)
                    # container subnet
                    tredlySelectContainerSubnet
                ;;
                6)
                    # api whitelist
                    tredlySelectApiWhitelist
                ;;
                *)
                    echo "Invalid input \"${_userSelection}\""
                ;;
            esac
       fi
    done
}

# allows user to select their external iface
function tredlySelectExternalInterface() {
    local _externalInterface
    local _userSelectInterface
    
    # get a list of interfaces
    IFS=$'\n' _interfaces=($( getExternalInterfaces ))
    
    # if only one interface was found then use that by default
    if [[ ${#_interfaces[@]} -eq 1 ]]; then
        _externalInterface="${_interfaces[0]}"
    else
        while [[ -z "${_externalInterface}" ]]; do
            # have the user select the interface
            echo "More than one interface was found on this machine:"
            for _i in ${!_interfaces[@]}; do
                echo "$(( ${_i} + 1 )). ${_interfaces[${_i}]}"
            done

            read -p "Which would you like to use as your external interface? " _userSelectInterface

            # ensure that the value we received lies within the bounds of the array
            if [[ ${_userSelectInterface} -lt 1 ]] || [[ ${_userSelectInterface} -gt ${#_interfaces[@]} ]] || ! is_int ${_userSelectInterface}; then
                e_error "Invalid selection. Please try again."
                _userSelectInterface=''
            elif [[ -n "$( ifconfig | grep "^${_interfaces[$(( ${_userSelectInterface} - 1 ))]}:" )" ]]; then
                _externalInterface="${_interfaces[$(( ${_userSelectInterface} - 1 ))]}"
            fi
        done
    fi
    
    # return what was selected
    _configOptions[1]="${_externalInterface}"
}

# allows user to set their ip address and cidr
function tredlySelectExternalIP() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "External IP Address: " _userInput
    
        # now validate it
        [[ ${_userInput} =~ ^(.*)\/([[:digit:]]+)$ ]]
        
        # validate the values
        if is_valid_ip4 "${BASH_REMATCH[1]}" && is_valid_cidr "${BASH_REMATCH[2]}"; then
            _valid="true"
            # set it in the global
            _configOptions[2]="${_userInput}"
        else
            echo "Please enter in the format ip/cidr. Eg. 10.99.0.0/16"
        fi
    done
}

function tredlySelectExternalGateway() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "External Gateway IP: " _userInput
    
        # validate the value
        if is_valid_ip4 "${_userInput}"; then
            _valid="true"
            # set it in the global
            _configOptions[3]="${_userInput}"
        else
            echo "Invalid IP4"
        fi
    done
}

# select and validate hostname
function tredlySelectHostname() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "Hostname: " _userInput
    
        # validate the value
        if is_valid_hostname "${_userInput}"; then
            _valid="true"
            # set it in the global
            _configOptions[4]="${_userInput}"
        else
            echo "Invalid Hostname. Please try again"
        fi
    done
}

# allows user to set their container (private) subnet
function tredlySelectContainerSubnet() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "Container Subnet: " _userInput
    
        # now validate it
        regex="^(.*)\/([[:digit:]]+)$"
        [[ ${_userInput} =~ ${regex} ]]
        
        # validate the values
        if is_valid_ip4 "${BASH_REMATCH[1]}" && is_valid_cidr "${BASH_REMATCH[2]}"; then
            _valid="true"
            # set it in the global
            _configOptions[5]="${_userInput}"
        else
            echo "Please enter in the format ip/cidr. Eg. 10.99.0.0/16"
        fi

    done
}

# allows user to set their tredly build repo
function tredlySelectBuildRepo() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "Tredly Build GIT URL: " _userInput
    
        # validate it
        if [[ -n "${_userInput}" ]]; then
            _valid="true"
            # set hte global
            _configOptions[6]="${_userInput}"
        fi
    done
}

# allows user to set their container (private) subnet
function tredlySelectBuildBranch() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "Tredly Build Branch Name: " _userInput
    
        # validate it
        if [[ -n "${_userInput}" ]]; then
            _valid="true"
            # set hte global
            _configOptions[7]="${_userInput}"
        fi
    done
}

# allows user to set their tredly-api URL
function tredlySelectAPIURL() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "Tredly Build GIT URL (blank for do not install): " _userInput
    
        _valid="true"
        # set the global
        _configOptions[8]="${_userInput}"
    done
}

# allows user to set their container (private) subnet
function tredlySelectAPIBranch() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "Tredly API Branch Name: " _userInput
        
        # validate it
        if [[ -n "${_userInput}" ]]; then
            _valid="true"
            # set the global
            _configOptions[9]="${_userInput}"
        fi
    done
}

# allows user to set their container (private) subnet
function tredlyDownloadSource() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "Tredly API Branch Name: " _userInput
        
        # validate it
        if [[ -n "${_userInput}" ]]; then
            _valid="true"
            # set the global
            _configOptions[9]="${_userInput}"
        fi
    done
}

function tredlySelectDownloadKernel() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "Download Kernel Source (y/n): " _userInput
        
        # validate it
        if [[ "${_userInput}" == "y" || "${_userInput}" == "n" ]]; then
            _valid="true"
            # set the global
            _configOptions[10]="${_userInput}"
        fi
    done
}

function tredlySelectApiWhitelist() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        echo "Please enter a list of ip addresses or network ranges, separated by commas"
        read -p "Tredly API Whitelist: " _userInput
        
        # validate it
        IFS=',' read -ra _whitelistArray <<< "${_userInput}"
        
        for ip in ${_whitelistArray[@]}; do
            if ! is_valid_ip_or_range "${ip}"; then
                e_error "${ip} is an invalid ip address or range"
                _valid="false"
            else
                _valid="true"
            fi
        done

        if [[ "${_valid}" == "true" ]]; then
            # set the global
            _configOptions[6]="${_userInput}"
        fi
    done
}