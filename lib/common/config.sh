#!/usr/bin/env bash

# associative arrays
declare -A _CONF_COMMON
declare -A _CONF_TREDLYFILE

# standard arrays for multiple line entries in tredlyfile
declare -a _CONF_COMMON_DNS
declare -a _CONF_TREDLYFILE_TCPIN
declare -a _CONF_TREDLYFILE_TCPOUT
declare -a _CONF_TREDLYFILE_UDPIN
declare -a _CONF_TREDLYFILE_UDPOUT
declare -a _CONF_TREDLYFILE_URL
declare -a _CONF_TREDLYFILE_URLCERT
declare -a _CONF_TREDLYFILE_URLWEBSOCKET
declare -a _CONF_TREDLYFILE_URLMAXFILESIZE
declare -a _CONF_TREDLYFILE_URLREDIRECT
declare -a _CONF_TREDLYFILE_URLREDIRECTCERT
declare -a _CONF_TREDLYFILE_TECHOPTIONS
declare -a _CONF_TREDLYFILE_STARTUP
declare -a _CONF_TREDLYFILE_SHUTDOWN
declare -a _CONF_TREDLYFILE_IP4WHITELIST
declare -a _CONF_TREDLYFILE_CUSTOMDNS

# Validates a common config file, for example tredly-host.conf
function common_conf_validate() {

    if [[ -z "${1}" ]]; then
        exit_with_error "common_conf_validate() cannot be called without passing at least 1 required field."
    fi

    ## Use 'required' from the common config to construct the required array
    local -a required
    IFS=',' read -a required <<< "${1}"

    ## Check for required fields
    for p in "${required[@]}"
    do
        # handle specific entries
        case "${p}" in
            dns)
                if [[ ${#_CONF_COMMON_DNS[@]} -eq 0 ]]; then
                    exit_with_error "'${p}' is missing or empty and is required. Check config"
            fi
            ;;
            *)
                if [ -z "${_CONF_COMMON[${p}]}" ]; then
                    exit_with_error "'${p}' is missing or empty and is required. Check config"
                fi
            ;;
        esac
    done

    return ${E_SUCCESS}
}

## Reads conf/{context}.conf, parsing it and storing each key/value pair
## in `_CONF_COMMON`. Path is built using _TREDLY_DIR, which is the directory
## that tredly script is running from.
## Arguments:
##      1. String. context. This must match the name of a config file (*.conf)
##
## Return:
##     - exits with error message if conf/{context}.conf does not exist
##
function common_conf_parse() {

    if [[ -z "${1}" ]]; then
        exit_with_error "common_conf_parse() cannot be called without providing a command as context"
    fi

    local context="${1}"

    if [ ! -e "${_TREDLY_DIR_CONF}/${context}.conf" ]; then
        e_verbose "No configuration found for \`${context}\`. Skipping."
        return ${E_SUCCESS}
    fi

    # empty our arrays
    _CONF_COMMON_DNS=()

    ## Read the data in
    local regexp="^[^#\;]*="

    while read line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[^#\;]*= ]]; then
            key="${line%%=*}"
            value="${line#*=}"
            # strip anything after a comment
            value=$( lcut "${value}" '#' )

            # strip any whitespace
            local strippedValue=$(strip_whitespace "${value}")

            # handle some lines specifically
            case "${key}" in
                lifNetwork)
                    # split it up
                    [[ ${value#*=} =~ ^(.+)/(.+)$ ]]

                    # assign the values
                    _CONF_COMMON[lifNetwork]=${BASH_REMATCH[1]}
                    _CONF_COMMON[lifCIDR]=${BASH_REMATCH[2]}
                    ;;
                dns)
                    _CONF_COMMON_DNS+=("${value}")
                    ;;
                *)
                    _CONF_COMMON[${key}]="${value}"
                    ;;
            esac
        fi
    done < "${_TREDLY_DIR_CONF}/${context}.conf"

    return ${E_SUCCESS}
}

## Reads TredlyFile in directory provided, parsing it and storing each key/value pair
## in `_CONF_TREDLYFILE`. Also checks that at least one of tcpInPorts
## and udpInPorts is set. Lastly, iterates over list of 'fileFolderMapping' and makes sure
## the src folder exists.
##
## Arguments:
##      1. String. Directory containging Tredlyfile. If this is an empty string, assume CWD
##      2. Boolean. Optional. Skip validation
##
## Return:
##     - exits with error message if Tredlyfile does not exist
##     - exits with error message if any of the required fields are not present
##
function tredlyfile_parse() {

    local tredlyFile key value strippedValue

    tredlyFile="${1}"

    if [ ! -f "${tredlyFile}" ]; then
        # error if the file doesnt exist, exiting the function gracefully
        return ${E_ERROR}
    fi

    # empty our arrays
    _CONF_TREDLYFILE_TCPIN=()
    _CONF_TREDLYFILE_TCPOUT=()
    _CONF_TREDLYFILE_UDPIN=()
    _CONF_TREDLYFILE_UDPOUT=()
    _CONF_TREDLYFILE_URL=()
    _CONF_TREDLYFILE_URLCERT=()
    _CONF_TREDLYFILE_URLWEBSOCKET=()
    _CONF_TREDLYFILE_URLMAXFILESIZE=()
    _CONF_TREDLYFILE_URLREDIRECT=()
    _CONF_TREDLYFILE_URLREDIRECTCERT=()
    _CONF_TREDLYFILE_TECHOPTIONS=()
    _CONF_TREDLYFILE_STARTUP=()
    _CONF_TREDLYFILE_SHUTDOWN=()
    _CONF_TREDLYFILE_IP4WHITELIST=()
    _CONF_TREDLYFILE_CUSTOMDNS=()

    ## Read the data in
    while read line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[^#\;]*= ]]; then

            key="${line%%=*}"
            value="${line#*=}"
            # strip anything after a comment
            lvalue=$( lcut "${value}" '#' )
            rvalue=$( rcut "${value}" '#' )

            # check if the hash was escaped or not, and if so then stick it back together
            if [[ ${lvalue} =~ \\$ ]]; then
                value="${lvalue}#${rvalue}"
            else
                value="${lvalue}"
            fi

            # strip any whitespace
            local strippedValue=$(strip_whitespace "${value}")
            local arrayKey=''
            # extract relevant keys from the tredlyfile declaration
            [[ ${key} =~ ^([a-zA-Z]+)([0-9]+) ]] && arrayKey="${BASH_REMATCH[2]}"

            # do different things based off certain commands
            case "${key}" in
                url[1-999])

                    # add it to the array if it actually contained data
                    if [[ -n "${strippedValue}" ]]; then
                        _CONF_TREDLYFILE_URL[${arrayKey}]="${value}"
                    fi
                    ;;
                url[1-999]Cert)
                    # add it to the array
                    _CONF_TREDLYFILE_URLCERT[${arrayKey}]="$( rtrim "${value}" '/' )"
                    ;;
                url[1-999]Websocket)
                    # add it to the array
                    _CONF_TREDLYFILE_URLWEBSOCKET[${arrayKey}]="${value}"

                    ;;
                url[1-999]MaxFileSize)
                    # validate it
                    if [[ -n "${value}" ]]; then
                        unit="${value: -1}"
                        unitValue="${value%?}"

                        if [[ "${unit}" == "g" ]] || [[ "${unit}" == "G" ]]; then
                            # convert it to megabytes
                            unitValue=$(( ${unitValue} * 1024 ))
                            unit="m"
                        fi
                        # allow a max of 2gb and default of 1mb
                        if [[ "${unit}" == "m" ]] && [[ "${unitValue}" -gt "2048" ]]; then
                            _CONF_TREDLYFILE_URLMAXFILESIZE[${arrayKey}]="2048m"
                        elif [[ "${unit}" == "m" ]] && [[ "${unitValue}" -le "2048" ]]; then
                            _CONF_TREDLYFILE_URLMAXFILESIZE[${arrayKey}]="${unitValue}${unit}"
                        else
                            # default to 1mb
                            _CONF_TREDLYFILE_URLMAXFILESIZE[${arrayKey}]="1m"
                        fi
                    fi

                    ;;
                url[1-999]Redirect[1-999])
                    # we can have multiple urlredirects per url so handle that with space separated string since space is encoded to %20 in urls
                    if [[ -n "${_CONF_TREDLYFILE_URLREDIRECT[${arrayKey}]}" ]]; then
                        # concatenate the urls
                        _CONF_TREDLYFILE_URLREDIRECT[${arrayKey}]="${_CONF_TREDLYFILE_URLREDIRECT[${arrayKey}]} $( rtrim "${value}" '/' )"
                    else
                        # add it to the array
                        _CONF_TREDLYFILE_URLREDIRECT[${arrayKey}]="$( rtrim "${value}" '/' )"
                    fi

                    ;;
                url[1-999]Redirect[1-999]Cert)
                    # if the value is blank then set the value to "null" so that the numbering within the string is correct
                    # and so we can tell that this has no associated cert
                    if [[ -z "${value}" ]]; then
                        value="null"
                    fi
                    # we can have multiple urlredirects per url so handle that with space separated string since space is encoded to %20 in urls
                    if [[ -n "${_CONF_TREDLYFILE_URLREDIRECTCERT[${arrayKey}]}" ]]; then
                        # concatenate the urls
                        _CONF_TREDLYFILE_URLREDIRECTCERT[${arrayKey}]="${_CONF_TREDLYFILE_URLREDIRECTCERT[${arrayKey}]} ${value}"
                    else
                        # add it to the array
                        _CONF_TREDLYFILE_URLREDIRECTCERT[${arrayKey}]="${value}"
                    fi
                    ;;
                tcpInPort)
                    # add it to the array if it actually contained data
                    if [[ -n "${strippedValue}" ]]; then
                        _CONF_TREDLYFILE_TCPIN+=("${value}")
                    fi
                    ;;
                udpInPort)
                    # add it to the array if it actually contained data
                    if [[ -n "${strippedValue}" ]]; then
                        _CONF_TREDLYFILE_UDPIN+=("${value}")
                    fi
                    ;;
                tcpOutPort)
                    # add it to the array if it actually contained data
                    if [[ -n "${strippedValue}" ]]; then
                        _CONF_TREDLYFILE_TCPOUT+=("${value}")
                    fi
                    ;;
                udpOutPort)
                    # add it to the array if it actually contained data
                    if [[ -n "${strippedValue}" ]]; then
                        _CONF_TREDLYFILE_UDPOUT+=("${value}")
                    fi
                    ;;
                technicalOptions)
                    # add it to the array if it actually contained data
                    if [[ -n "${strippedValue}" ]]; then
                        # strip out the technical options key to check that it is valid
                        techOptionsKey="${strippedValue%%=*}"
                        # validate it
                        if array_contains_substring VALID_TECHNICAL_OPTIONS[@] "^${techOptionsKey}$"; then
                            _CONF_TREDLYFILE_TECHOPTIONS+=("${value}")
                        fi
                    fi
                    ;;
                # startup commands
                onStart)
                    # add the entire line to the array to be interpreted later
                    if [[ -n "${strippedValue}" ]]; then
                        _CONF_TREDLYFILE_STARTUP+=("${key}=${value}")
                    fi
                    ;;
                installPackage|fileFolderMapping)
                    # add the entire line to the array to be interpreted later
                    if [[ -n "${strippedValue}" ]]; then
                        _CONF_TREDLYFILE_STARTUP+=("${key}=${value}")
                    fi
                    ;;
                partitionFolder)
                    if [[ -n "${strippedValue}" ]]; then
                        _CONF_TREDLYFILE_STARTUP+=("${key}=${value}")
                    fi
                    ;;
                persistentMountPoint)
                    if [[ -n "${strippedValue}" ]]; then
                        _CONF_TREDLYFILE_STARTUP+=("${key}=${value}")
                        # add it to the standard tredlyfile array too as we need it there
                        _CONF_TREDLYFILE[${key}]="${value}"
                    fi
                    ;;
                # shutdown commands
                onStop)
                    # add the entire line to the array to be interpreted later
                    if [[ -n "${strippedValue}" ]]; then
                        _CONF_TREDLYFILE_SHUTDOWN+=("${key}=${value}")
                    fi
                    ;;
                # whitelisted ip addresses for this container
                ipv4Whitelist)
                    if [[ -n "${strippedValue}" ]]; then
                        _CONF_TREDLYFILE_IP4WHITELIST+=("${strippedValue}")
                    fi
                    ;;
                # custom DNS for this container
                customDNS)
                    if [[ -n "${strippedValue}" ]]; then
                        _CONF_TREDLYFILE_CUSTOMDNS+=("${value}")
                    fi
                    ;;
                *)
                    _CONF_TREDLYFILE[${key}]="${value}"
                    ;;
            esac
        fi
    done < $tredlyFile

    # set some default values if they werent set
    if [[ -z "${_CONF_TREDLYFILE[containerVersion]}" ]]; then
        _CONF_TREDLYFILE[containerVersion]=1
    fi
    if [[ -z "${_CONF_TREDLYFILE[startOrder]}" ]]; then
        _CONF_TREDLYFILE[startOrder]=1
    fi
    if [[ -z "${_CONF_TREDLYFILE[replicate]}" ]]; then
        _CONF_TREDLYFILE[replicate]="no"
    fi
    if [[ -z "${_CONF_TREDLYFILE[layer4Proxy]}" ]]; then
        _CONF_TREDLYFILE[layer4Proxy]="no"
    fi
    if [[ -z "${_CONF_TREDLYFILE[maxCpu]}" ]]; then
        _CONF_TREDLYFILE[maxCpu]="unlimited"
    fi
    if [[ -z "${_CONF_TREDLYFILE[maxHdd]}" ]]; then
        _CONF_TREDLYFILE[maxHdd]="unlimited"
    fi
    if [[ -z "${_CONF_TREDLYFILE[maxRam]}" ]]; then
        _CONF_TREDLYFILE[maxRam]="unlimited"
    fi

    # check if we have set "any" for any outgoing ports, if so then get rid of the rest of the ports as they are redundant
    if array_contains_substring _CONF_TREDLYFILE_TCPOUT[@] '^any$'; then
        _CONF_TREDLYFILE_TCPOUT=("any")
    fi
    if array_contains_substring _CONF_TREDLYFILE_UDPOUT[@] '^any$'; then
        _CONF_TREDLYFILE_UDPOUT=("any")
    fi
    if array_contains_substring _CONF_TREDLYFILE_TCPIN[@] '^any$'; then
        _CONF_TREDLYFILE_TCPIN=("any")
    fi
    if array_contains_substring _CONF_TREDLYFILE_UDPIN[@] '^any$'; then
        _CONF_TREDLYFILE_UDPIN=("any")
    fi

    ## Skip the validation if need be
    if [[ (-z "${2}") || ("${2}" = false) ]]; then
        tredlyfile_validate
    fi

    return ${E_SUCCESS}

}

## Checks for the require fields specified in the tredly-host.conf.
## Also checks that at least one of tcpInPorts
## and udpInPorts is set. Lastly, iterates over list of 'fileFolderMapping' and makes sure
## the src folder exists.
##
## Return:
##     - exits with error message if any of the required fields are not present
##
function tredlyfile_validate() {
    ## Use 'required' from the common config to construct the required array
    local -a required
    IFS=',' read -a required <<< "${_CONF_COMMON[required]}"
    
    # extract the major and minor versions from tredly and tredlyfile version
    local _regex="^([[:digit:]]+)\.([[:digit:]]+)\.([[:digit:]]+)"
    [[ ${_VERSIONNUMBER} =~ ${_regex} ]]
    
    local _tredlyVersionMajor="${BASH_REMATCH[1]}"
    local _tredlyVersionMinor="${BASH_REMATCH[2]}"
    
    # extract the major and minor versions from tredlyfile version
    [[ ${_CONF_TREDLYFILE[versionNumber]} =~ ${_regex} ]]
    local _fileVersionMajor="${BASH_REMATCH[1]}"
    local _fileVersionMinor="${BASH_REMATCH[2]}"

    # ensure the tredlyfile we are processing is the same version as this version of tredly (major + minor)
    if [[ "${_tredlyVersionMajor}" != "${_fileVersionMajor}" ]] || \
       [[ "${_tredlyVersionMinor}" != "${_fileVersionMinor}" ]]; then
        exit_with_error "Tredlyfile version ${_CONF_TREDLYFILE[versionNumber]} does not match this version of Tredly. Please update your Tredlyfile to version ${_tredlyVersionMajor}.${_tredlyVersionMinor}.0 and try again."
    fi

    ## Validate the contents. Check for required fields
    for p in "${required[@]}"
    do
        if [ -z "${_CONF_TREDLYFILE[${p}]}" ]; then
            exit_with_error "'${p}' is missing or empty and is required. Check Tredlyfile"
        fi
    done

    # if container group is set and startOrder isnt
    if [[ -n "${_CONF_TREDLYFILE[containerGroup]}" ]] && [[ -z "${_CONF_TREDLYFILE[startOrder]}" ]]; then
        exit_with_error "containerGroup is set but startOrder is not. Check Tredlyfile"
    fi
    # if containerGroup is set and replicate isnt
    if [[ -n "${_CONF_TREDLYFILE[containerGroup]}" ]] && [[ -z "${_CONF_TREDLYFILE[replicate]}" ]]; then
        exit_with_error "containerGroup is set but replicate is not. Check Tredlyfile"
    fi

    # make sure one of tcpinports or udpinports is set
    if [[ ${#_CONF_TREDLYFILE_TCPIN[@]} -eq 0 ]] && [[ ${#_CONF_TREDLYFILE_UDPIN[@]} -eq 0 ]]; then
        exit_with_error "'tcpInPort' and 'udpInPort' are both missing or empty. At least one is required. Check Tredlyfile"
    fi

    # Ensure that each urlredirect has its own certificate
    local _i
    local _redirectUrl
    local -a _redirectUrls
    local -a _redirectCerts
    # loop over each url
    for _i in ${!_CONF_TREDLYFILE_URLREDIRECT[@]}; do
        # and each redirect for this url
        IFS=' ' _redirectUrls=(${_CONF_TREDLYFILE_URLREDIRECT[${_i}]})
        IFS=' ' _redirectCerts=(${_CONF_TREDLYFILE_URLREDIRECTCERT[${_i}]})

        IFS=' '
        # compare array lengths
        if [[ ${#_redirectUrls[@]} != ${#_redirectCerts[@]} ]]; then
            exit_with_error "url1: number of redirect urls does not match number of redirect certificates. If you are redirecting a HTTP URL, please include a blank definition."
        fi
    done

    # ensure that HTTP or HTTPS ports are open if user specified a URL
    if [[ ${#_CONF_TREDLYFILE_URL[@]} -gt 0 ]]; then
        # loop over the urls
        for _i in ${!_CONF_TREDLYFILE_URL[@]}; do
            # check HTTP only urls - if urlcert is blank and port 80 isnt open
            if [[ -z "${_CONF_TREDLYFILE_URLCERT[${_i}]}" ]] && \
               ! array_contains_substring _CONF_TREDLYFILE_TCPIN[@] '^80$' && \
               ! array_contains_substring _CONF_TREDLYFILE_TCPIN[@] '^any$'; then
                exit_with_error "HTTP URL ${_CONF_TREDLYFILE_URL[${_i}]} specified but TCP IN port 80 is not set. Please set tcpInPort=80 in your Tredlyfile"
            fi
            # check HTTPS urls - if urlcert is not blank and port 443 isnt open
            if [[ -n "${_CONF_TREDLYFILE_URLCERT[${_i}]}" ]] && \
               ! array_contains_substring _CONF_TREDLYFILE_TCPIN[@] '^443$' && \
               ! array_contains_substring _CONF_TREDLYFILE_TCPIN[@] '^any$'; then
                exit_with_error "HTTPS URL ${_CONF_TREDLYFILE_URL[${_i}]} specified but TCP IN port 443 is not set. Please set tcpInPort=443 in your Tredlyfile"
            fi
        done
    fi

    # make sure that a mount point is specified if persistent storage is selected
    #if [[ -n "${_CONF_TREDLYFILE[persistentStorageUUID]}" ]] && ! array_contains_substring _CONF_TREDLYFILE_STARTUP[@] "^persistentMountPoint="; then
        #exit_with_error "'persistentStorageUUID' is specified but no mount point specified. Please specify a mount point in your Tredlyfile."
    #fi
    IFS=','
    ## Check that fileFolderMapping is set up correctly
    for _item in ${_CONF_TREDLYFILE_STARTUP[@]}; do
        # trim the item
        _item="$( trim "${_item}" )"

        # make sure we're processing filefoldermappings
        if [[ ${_item} =~ ^fileFolderMapping= ]]; then
            # get rid of the filefoldermapping part
            _item=="${_item#*=}"
            _item=$( ltrim "${_item}" '=' )
            _item=$( trim "${_item}" )
            
            regex="^([^ ]+)[[:space:]]([^ ]+)"
            
            [[ ${_item} =~ ${regex} ]]
            src="${BASH_REMATCH[1]}"
            dest=$(rtrim "${BASH_REMATCH[2]}" /)

            # make sure the filefoldermapping starts with partition/ (partition data) or / (container data)
            if [[ ! "${src}" =~ ^partition/ ]] && [[ ! "${src}" =~ ^/ ]]; then
                exit_with_error "fileFolderMapping ${src} ${dest} must start with / (container data) or partition/ (partition data)"
            fi
        fi
    done
    
    
    IFS=','
    ## Check that certs are set up correctly
    for _item in ${_CONF_TREDLYFILE_URLCERT[@]}; do
        # trim the item
        _item="$( trim "${_item}" )"

        # make sure the filefoldermapping starts with partition/ (partition data) or / (container data)
        if [[ ! "${_item}" =~ ^partition/ ]] && [[ ! "${_item}" =~ ^/ ]]; then
            exit_with_error "urlCert ${_item} must start with / (container data) or partition/ (partition data)"
        fi
    done
    
    ## Check that certs are set up correctly
    for _line in ${_CONF_TREDLYFILE_URLREDIRECTCERT[@]}; do
        # split them out
        IFS=' '
        for _item in ${_line}; do
            # trim the item
            _item="$( trim "${_item}" )"

            # make sure the filefoldermapping starts with partition/ (partition data) or / (container data)
            if [[ ! "${_item}" =~ ^partition/ ]] && [[ ! "${_item}" =~ ^/ ]]; then
                exit_with_error "urlRedirectCert ${_item} must start with / (container data) or partition/ (partition data)"
            fi
        done
    done

    return ${E_SUCCESS}
}
