#!/usr/local/bin/bash

_testName="Create Container"
_tredlyFilePath="/localdev/tredly/tests/containers/www"
_containerName="wwwtest"
_partitionName="tests"

# TODO: load this from tredly-host
_layer7ProxyIP4="10.99.255.254"

declare -a _TESTS_PASSED
declare -a _TESTS_FAILED

# include tredly libs
for f in /usr/local/lib/tredly/bash-common/*.sh; do source ${f}; done

# read the tredlyfile for this script
_tredlyFile="$( rtrim ${_tredlyFilePath} '/' )/tredly.json"

# Parse the tredlyfile, and exit with an error if it doesnt exist
if [[ ! -f "${_tredlyFile}" ]]; then
    exit_with_error "No Tredlyfile found at ${_tredlyFile}"
elif ! tredlyfile_parse "${_tredlyFile}"; then
    exit_with_error "Tredlyfile was invalid at ${_tredlyFile}"
fi

_exitCode=0

e_header "Running test '${_testName}'"

e_note "Creating Container..."
tredly replace container ${_partitionName} --location=${_tredlyFilePath} --containerName=${_containerName}

if [[ $? -ne 0 ]]; then
   e_error "Failed to create container"
   exit 1
fi

# get the uuid of the just created container
_uuid=$( tredly list containers ${_partitionName} | grep ${_containerName} | awk '{ print $4 }' )

# set the root path to the container
_containerRoot="/tredly/ptn/${_partitionName}/cntr/${_uuid}/root"
_containerIP4=$( tredly list containers ${_partitionName} | grep ${_uuid} | awk '{ print $5 }' )

# if the uuid wasnt found then it could indicate that the container name failed to apply
if [[ -z "${_uuid}" ]]; then
    e_error "Could not find uuid - did --containerName= work?"
    exit 1
fi


# check technicaloptions
if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[securelevel]}" ]]; then
    _containerSecureLevel=$( jls -j trd-${_uuid} securelevel)
    
    if [[ ${_containerSecureLevel} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[securelevel]} ]]; then
        e_success "Technicaloptions: securelevel passed"
        _TESTS_PASSED+=('Technical Options: securelevel')
    else
        e_error "FAILED: technicaloptions: securelevel"
        _TESTS_FAILED+=("Technical Options: securelevel ${_containerSecureLevel} should be ${_CONF_TREDLYFILE_TECHOPTIONS[securelevel]}")
        _exitCode=1
    fi
fi
    
if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[devfs_ruleset]}" ]]; then
    _containerDevfsRuleset=$( jls -j trd-${_uuid} devfs_ruleset )
    if [[ ${_containerDevfsRuleset} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[devfs_ruleset]} ]]; then
        e_success "Technicaloptions: devfs_ruleset passed"
        _TESTS_PASSED+=('Technical Options: devfs_ruleset')
    else
        e_error "FAILED: technicaloptions: devfs_ruleset"
        _TESTS_FAILED+=("Technical Options: devfs_ruleset ${_containerDevfsRuleset} should be ${_CONF_TREDLYFILE_TECHOPTIONS[devfs_ruleset]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[enforce_statfs]}" ]]; then
    _containerEnforceStatfs=$( jls -j trd-${_uuid} enforce_statfs )
    if [[ ${_containerEnforceStatfs} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[enforce_statfs]} ]]; then
        e_success "Technicaloptions: enforce_statfs passed"
        _TESTS_PASSED+=('Technical Options: enforce_statfs')
    else
        e_error "FAILED: technicaloptions: enforce_statfs"
        _TESTS_FAILED+=("Technical Options: enforce_statfs ${_containerEnforceStatfs} should be ${_CONF_TREDLYFILE_TECHOPTIONS[enforce_statfs]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[children_max]}" ]]; then
    _containerChildrenMax=$( jls -j trd-${_uuid} children.max )
    if [[ ${_containerChildrenMax} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[children_max]} ]]; then
        e_success "Technicaloptions: children_max passed"
        _TESTS_PASSED+=('Technical Options: children_max')
    else
        e_error "FAILED: technicaloptions: children_max"
        _TESTS_FAILED+=("Technical Options: children_max ${_containerChildrenMax} should be ${_CONF_TREDLYFILE_TECHOPTIONS[children_max]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[allow_set_hostname]}" ]]; then
    _containerAllowSetHostname=$( jls -j trd-${_uuid} allow.set_hostname )
    
    if [[ ${_containerAllowSetHostname} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[allow_set_hostname]} ]]; then
        e_success "Technicaloptions: allow_set_hostname passed"
        _TESTS_PASSED+=('Technical Options: allow_set_hostname')
    else
        e_error "FAILED: technicaloptions: allow_set_hostname"
        _TESTS_FAILED+=("Technical Options: allow_set_hostname ${_containerAllowSetHostname} should be ${_CONF_TREDLYFILE_TECHOPTIONS[allow_set_hostname]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[allow_sysvipc]}" ]]; then
    _containerAllowSysvipc=$( jls -j trd-${_uuid} allow.sysvipc )
    
    if [[ ${_containerAllowSysvipc} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[allow_sysvipc]} ]]; then
        e_success "Technicaloptions: allow_sysvipc passed"
        _TESTS_PASSED+=('Technical Options: allow_sysvipc')
    else
        e_error "FAILED: technicaloptions: allow_sysvipc"
        _TESTS_FAILED+=("Technical Options: allow_sysvipc ${_containerAllowSysvipc} should be ${_CONF_TREDLYFILE_TECHOPTIONS[allow_sysvipc]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[allow_raw_sockets]}" ]]; then
    _containerAllowRawSockets=$( jls -j trd-${_uuid} allow.raw_sockets )
    
    if [[ ${_containerAllowRawSockets} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[allow_raw_sockets]} ]]; then
        e_success "Technicaloptions: allow_raw_sockets passed"
        _TESTS_PASSED+=('Technical Options: allow_raw_sockets')
    else
        e_error "FAILED: technicaloptions: allow_raw_sockets"
        _TESTS_FAILED+=("Technical Options: allow_raw_sockets ${_containerAllowRawSockets} should be ${_CONF_TREDLYFILE_TECHOPTIONS[allow_raw_sockets]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[allow_chflags]}" ]]; then
    _containerAllowChflags=$( jls -j trd-${_uuid} allow.chflags )
    
    if [[ ${_containerAllowChflags} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[allow_chflags]} ]]; then
        e_success "Technicaloptions: allow_chflags passed"
        _TESTS_PASSED+=('Technical Options: allow_chflags')
    else
        e_error "FAILED: technicaloptions: allow_chflags"
        _TESTS_FAILED+=("Technical Options: allow_chflags ${_containerAllowChflags} should be ${_CONF_TREDLYFILE_TECHOPTIONS[allow_chflags]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[allow_mount]}" ]]; then
    _containerAllowMount=$( jls -j trd-${_uuid} allow.mount )
    
    if [[ ${_containerAllowMount} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[allow_mount]} ]]; then
        e_success "Technicaloptions: allow_mount passed"
        _TESTS_PASSED+=('Technical Options: allow_mount')
    else
        e_error "FAILED: technicaloptions: allow_mount"
        _TESTS_FAILED+=("Technical Options: allow_mount ${_containerAllowMount} should be ${_CONF_TREDLYFILE_TECHOPTIONS[allow_mount]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[allow_mount_devfs]}" ]]; then
    _containerAllowMountDevfs=$( jls -j trd-${_uuid} allow.mount.devfs )
    
    if [[ ${_containerAllowMountDevfs} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[allow_mount_devfs]} ]]; then
        e_success "Technicaloptions: allow_mount_devfs passed"
        _TESTS_PASSED+=('Technical Options: allow_mount_devfs')
    else
        e_error "FAILED: technicaloptions: allow_mount_devfs"
        _TESTS_FAILED+=("Technical Options: allow_mount_devfs ${_containerAllowMountDevfs} should be ${_CONF_TREDLYFILE_TECHOPTIONS[allow_mount_devfs]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[allow_mount_nullfs]}" ]]; then
    _containerAllowMountNullfs=$( jls -j trd-${_uuid} allow.mount.nullfs )
    
    if [[ ${_containerAllowMountNullfs} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[allow_mount_nullfs]} ]]; then
        e_success "Technicaloptions: allow_mount_nullfs passed"
        _TESTS_PASSED+=('Technical Options: allow_mount_nullfs')
    else
        e_error "FAILED: technicaloptions: allow_mount_nullfs"
        _TESTS_FAILED+=("Technical Options: allow_mount_nullfs ${_containerAllowMountNullfs} should be ${_CONF_TREDLYFILE_TECHOPTIONS[allow_mount_nullfs]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[allow_mount_procfs]}" ]]; then
    _containerAllowMountProcfs=$( jls -j trd-${_uuid} allow.mount.procfs )
    
    if [[ ${_containerAllowMountProcfs} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[allow_mount_procfs]} ]]; then
        e_success "Technicaloptions: allow_mount_procfs passed"
        _TESTS_PASSED+=('Technical Options: allow_mount_procfs')
    else
        e_error "FAILED: technicaloptions: allow_mount_procfs"
        _TESTS_FAILED+=("Technical Options: allow_mount_procfs ${_containerAllowMountProcfs} should be ${_CONF_TREDLYFILE_TECHOPTIONS[allow_mount_procfs]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[allow_mount_tmpfs]}" ]]; then
    _containerAllowMountTmpfs=$( jls -j trd-${_uuid} allow.mount.tmpfs  )
    
    if [[ ${_containerAllowMountTmpfs} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[allow_mount_tmpfs]} ]]; then
        e_success "Technicaloptions: allow_mount_tmpfs passed"
        _TESTS_PASSED+=('Technical Options: allow_mount_tmpfs')
    else
        e_error "FAILED: technicaloptions: allow_mount_tmpfs"
        _TESTS_FAILED+=("Technical Options: allow_mount_tmpfs ${_containerAllowMountTmpfs} should be ${_CONF_TREDLYFILE_TECHOPTIONS[allow_mount_tmpfs]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[allow_mount_zfs]}" ]]; then
    _containerAllowMountZfs=$( jls -j trd-${_uuid} allow.mount.zfs )
    
    if [[ ${_containerAllowMountZfs} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[allow_mount_zfs]} ]]; then
        e_success "Technicaloptions: allow_mount_zfs passed"
        _TESTS_PASSED+=('Technical Options: allow_mount_zfs')
    else
        e_error "FAILED: technicaloptions: allow_mount_zfs"
        _TESTS_FAILED+=("Technical Options: allow_mount_zfs ${_containerAllowMountZfs} should be ${_CONF_TREDLYFILE_TECHOPTIONS[allow_mount_zfs]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[allow_quotas]}" ]]; then
    _containerAllowQuotas=$( jls -j trd-${_uuid} allow.quotas )
    
    if [[ ${_containerAllowQuotas} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[allow_quotas]} ]]; then
        e_success "Technicaloptions: allow_quotas passed"
        _TESTS_PASSED+=('Technical Options: allow_quotas')
    else
        e_error "FAILED: technicaloptions: allow_quotas"
        _TESTS_FAILED+=("Technical Options: allow_quotas ${_containerAllowQuotas} should be ${_CONF_TREDLYFILE_TECHOPTIONS[allow_quotas]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[allow_socket_af]}" ]]; then
    _containerAllowSocketAf=$( jls -j trd-${_uuid} allow.socket_af )
    
    if [[ ${_containerAllowSocketAf} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[allow_socket_af]} ]]; then
        e_success "Technicaloptions: allow_socket_af passed"
        _TESTS_PASSED+=('Technical Options: allow_socket_af')
    else
        e_error "FAILED: technicaloptions: allow_socket_af"
        _TESTS_FAILED+=("Technical Options: allow_socket_af ${_containerAllowSocketAf} should be ${_CONF_TREDLYFILE_TECHOPTIONS[allow_socket_af]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[exec_prestart]}" ]]; then
    _containerExecPrestart=$( jls -j trd-${_uuid} exec.prestart )
    
    if [[ ${_containerExecPrestart} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[exec_prestart]} ]]; then
        e_success "Technicaloptions: exec_prestart passed"
        _TESTS_PASSED+=('Technical Options: exec_prestart')
    else
        e_error "FAILED: technicaloptions: exec_prestart"
        _TESTS_FAILED+=("Technical Options: exec_prestart ${_containerExecPrestart} should be ${_CONF_TREDLYFILE_TECHOPTIONS[exec_prestart]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[exec_poststart]}" ]]; then
    _containerExecPostStart=$( jls -j trd-${_uuid} exec.poststart )
    
    if [[ ${_containerExecPostStart} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[exec_poststart]} ]]; then
        e_success "Technicaloptions: exec_poststart passed"
        _TESTS_PASSED+=('Technical Options: exec_poststart')
    else
        e_error "FAILED: technicaloptions: exec_poststart"
        _TESTS_FAILED+=("Technical Options: exec_poststart ${_containerExecPostStart} should be ${_CONF_TREDLYFILE_TECHOPTIONS[exec_poststart]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[exec_prestop]}" ]]; then
    _containerExecPreStop=$( jls -j trd-${_uuid} exec.prestop )
    
    if [[ ${_containerExecPreStop} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[exec_prestop]} ]]; then
        e_success "Technicaloptions: exec_prestop passed"
        _TESTS_PASSED+=('Technical Options: exec_prestop')
    else
        e_error "FAILED: technicaloptions: exec_prestop"
        _TESTS_FAILED+=("Technical Options: exec_prestop ${_containerExecPreStop} should be ${_CONF_TREDLYFILE_TECHOPTIONS[exec_prestop]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[exec_stop]}" ]]; then
    _containerExecStop=$( jls -j trd-${_uuid} exec.stop )
    
    if [[ ${_containerExecStop} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[exec_stop]} ]]; then
        e_success "Technicaloptions: exec_stop passed"
        _TESTS_PASSED+=('Technical Options: exec_stop')
    else
        e_error "FAILED: technicaloptions: exec_stop"
        _TESTS_FAILED+=("Technical Options: exec_stop ${_containerExecStop} should be ${_CONF_TREDLYFILE_TECHOPTIONS[exec_stop]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[exec_clean]}" ]]; then
    _containerExecClean=$( jls -j trd-${_uuid} exec.clean )
    
    if [[ ${_containerExecClean} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[exec_clean]} ]]; then
        e_success "Technicaloptions: exec_clean passed"
        _TESTS_PASSED+=('Technical Options: exec_clean')
    else
        e_error "FAILED: technicaloptions: exec_clean"
        _TESTS_FAILED+=("Technical Options: exec_clean ${_containerExecClean} should be ${_CONF_TREDLYFILE_TECHOPTIONS[exec_clean]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[exec_timeout]}" ]]; then
    _containerExecTimeout=$( jls -j trd-${_uuid} exec.timeout )
    
    if [[ ${_containerExecTimeout} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[exec_timeout]} ]]; then
        e_success "Technicaloptions: exec_timeout passed"
        _TESTS_PASSED+=('Technical Options: exec_timeout')
    else
        e_error "FAILED: technicaloptions: exec_timeout"
        _TESTS_FAILED+=("Technical Options: exec_timeout ${_containerExecTimeout} should be ${_CONF_TREDLYFILE_TECHOPTIONS[exec_timeout]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[exec_fib]}" ]]; then
    _containerExecFib=$( jls -j trd-${_uuid} exec.fib )
    
    if [[ ${_containerExecFib} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[exec_fib]} ]]; then
        e_success "Technicaloptions: exec_fib passed"
        _TESTS_PASSED+=('Technical Options: exec_fib')
    else
        e_error "FAILED: technicaloptions: exec_fib"
        _TESTS_FAILED+=("Technical Options: exec_fib ${_containerExecFib} should be ${_CONF_TREDLYFILE_TECHOPTIONS[exec_fib]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[stop_timeout]}" ]]; then
    _containerStopTimeout=$( jls -j trd-${_uuid} stop.timeout )
    
    if [[ ${_containerStopTimeout} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[stop_timeout]} ]]; then
        e_success "Technicaloptions: stop_timeout passed"
        _TESTS_PASSED+=('Technical Options: stop_timeout')
    else
        e_error "FAILED: technicaloptions: stop_timeout"
        _TESTS_FAILED+=("Technical Options: stop_timeout ${_containerStopTimeout} should be ${_CONF_TREDLYFILE_TECHOPTIONS[stop_timeout]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[mount_devfs]}" ]]; then
    _containerMountDevfs=$( jls -j trd-${_uuid} mount.devfs )
    
    if [[ ${_containerMountDevfs} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[mount_devfs]} ]]; then
        e_success "Technicaloptions: mount_devfs passed"
        _TESTS_PASSED+=('Technical Options: mount_devfs')
    else
        e_error "FAILED: technicaloptions: mount_devfs"
        _TESTS_FAILED+=("Technical Options: mount_devfs ${_containerMountDevfs} should be ${_CONF_TREDLYFILE_TECHOPTIONS[mount_devfs]}")
        _exitCode=1
    fi
fi

if [[ -n "${_CONF_TREDLYFILE_TECHOPTIONS[mount_fdescfs]}" ]]; then
    _containerMountFdescfs=$( jls -j trd-${_uuid} mount.fdescfs )
    
    if [[ ${_containerMountFdescfs} -eq ${_CONF_TREDLYFILE_TECHOPTIONS[mount_fdescfs]} ]]; then
        e_success "Technicaloptions: mount_fdescfs passed"
        _TESTS_PASSED+=('Technical Options: mount_fdescfs')
    else
        e_error "FAILED: technicaloptions: mount_fdescfs"
        _TESTS_FAILED+=("Technical Options: mount_fdescfs ${_containerMountFdescfs} should be ${_CONF_TREDLYFILE_TECHOPTIONS[mount_fdescfs]}")
        _exitCode=1
    fi
fi

# check Resource limits

# CPU

if [[ -n "${_CONF_TREDLYFILE[maxCpu]}" ]] && [[ "${_CONF_TREDLYFILE[maxCpu]}" != 'unlimited' ]]; then
    e_header "Checking maxCpu"
    _containerCPU=$( rctl | grep "^jail:trd-${_uuid}:pcpu" | cut -d'=' -f 2)

    if [[ "${_containerCPU}" != "${_CONF_TREDLYFILE[maxCpu]::-1}" ]]; then
        e_error "Reported MaxCPU value ${_containerCPU} does not match tredlyfile value ${_CONF_TREDLYFILE[maxCpu]}"
        _exitCode=1
        _TESTS_FAILED+=('RLimits: maxCpu')
    else
        e_success "MaxCPU check passed"
        _TESTS_PASSED+=('RLimits: maxCpu')
    fi
fi

# MAX RAM
if [[ -n "${_CONF_TREDLYFILE[maxRam]}" ]] && [[ "${_CONF_TREDLYFILE[maxRam]}" != "unlimited" ]]; then
    e_header "Checking maxRam"
    _containerRAM=$( rctl | grep "^jail:trd-${_uuid}:memoryuse" | cut -d'=' -f 2)
    
    # convert maxram to bytes
    _maxRamTredlyfileBytes=$( convert_size_unit "${_CONF_TREDLYFILE[maxRam]}g" "b" )

    if [[ "${_containerRAM}" != "${_maxRamTredlyfileBytes}" ]]; then
        e_error "Reported maxRAM value ${_containerRAM} does not match tredlyfile value ${_CONF_TREDLYFILE[maxRam]}"
        _exitCode=1
        _TESTS_FAILED+=('RLimits: maxRam')
    else
        e_success "maxRAM check passed"
        _TESTS_PASSED+=('RLimits: maxRam')
    fi
fi

# MAX HDD
if [[ -n "${_CONF_TREDLYFILE[maxHdd]}" ]] && [[ "${_CONF_TREDLYFILE[maxHdd]}" != "unlimited" ]]; then
    e_header "Checking maxHdd"
    _containerHDD=$( zfs get -H -o value quota zroot/tredly/ptn/${_partitionName}/cntr/${_uuid} )
    
    # strip the last char of the zfs value before comparing
    if [[ "${_containerHDD::-1}" != "${_CONF_TREDLYFILE[maxHdd]}" ]]; then
        e_error "Reported MaxHDD value ${_containerHDD::-1} does not match tredlyfile value ${_CONF_TREDLYFILE[maxHdd]}"
        _exitCode=1
        _TESTS_FAILED+=('RLimits: maxHdd')
    else
        e_success "MaxHDD check passed"
        _TESTS_PASSED+=('RLimits: maxHdd')
    fi
fi

e_header "Checking URLs"
# check responsiveness of URLs
for key in "${!_CONF_TREDLYFILE_URL[@]}"
do
    # strip out the host so we can fake it
    _urlHost=$(rcut "${_CONF_TREDLYFILE_URL[${key}]}" '://' )
    _urlHost=$(lcut "${_urlHost}" '/' )
    
    # strip the protocol from the url
    _url=$(rcut "${_CONF_TREDLYFILE_URL[${key}]}" '://' )
    
    # check if its a http or https url
    if [[ -z "${_CONF_TREDLYFILE_URLCERT[${key}]}" ]]; then
        # its a http url
        _proto="http"
        _port="80"
    else
        _proto="https"
        _port="443"
    fi

    # check the connectivity from the hosts private interface directly to the container
    _curlResult=$( curl -I -k --connect-timeout 10 --interface bridge1 --resolve ${_urlHost}:${_port}:${_containerIP4}  ${_proto}://${_url} )
    _statusCode=$( echo "${_curlResult}" | head -n 1 | cut -d' ' -f 2 )
    
    if [[ ${_statusCode} -eq 200 ]]; then
        _TESTS_PASSED+=("Connection from L7Proxy ${_url}: ${_statusCode}")
    else
        _TESTS_FAILED+=("Connection from L7Proxy ${_url}: ${_statusCode}")
    fi
    
    # check the HTTPS connectivity from the hosts private interface to the layer 7 proxy
    _curlResult=$( curl -I -k --connect-timeout 10 --interface bridge1 --resolve ${_urlHost}:443:${_layer7ProxyIP4}  https://${_url} )
    _statusCode=$( echo "${_curlResult}" | head -n 1 | cut -d' ' -f 2 )
    
    if [[ ${_statusCode} -eq 200 ]] || [[ ${_statusCode} -eq 301 ]]; then
        _TESTS_PASSED+=("Connection to L7Proxy https://${_url}: ${_statusCode}")
    else
        _TESTS_FAILED+=("Connection to L7Proxy https://${_url}: ${_statusCode}")
    fi
    
     # check the HTTP connectivity from the hosts private interface to the layer 7 proxy
    _curlResult=$( curl -I -k --connect-timeout 10 --interface bridge1 --resolve ${_urlHost}:80:${_layer7ProxyIP4}  http://${_url} )
    _statusCode=$( echo "${_curlResult}" | head -n 1 | cut -d' ' -f 2 )
    
    if [[ ${_statusCode} -eq 200 ]] || [[ ${_statusCode} -eq 301 ]]; then
        _TESTS_PASSED+=("Connection to L7Proxy http://${_url}: ${_statusCode}")
    else
        _TESTS_FAILED+=("Connection to L7Proxy http://${_url}: ${_statusCode}")
    fi
done

# check websocket

# check max file size


####
# check layer 4 proxy

# check firewall rules

# check ipv4 whitelist

# check persistent storage
if [[ -n "${_CONF_TREDLYFILE[persistentStorageUUID]}" ]]; then
    e_header "Checking Persistent Storage"
    
    _persistentDataset="zroot/tredly/ptn/${_partitionName}/psnt/${_CONF_TREDLYFILE[persistentStorageUUID]}"

    _zfsFound=$( zfs list -H "${_persistentDataset}" | wc -l  | tr -d '[[:space:]]')

    if [[ ${_zfsFound} -eq 1 ]]; then
        _TESTS_PASSED+=('Persistent Storage: ZFS Dataset created')
    else
        _TESTS_FAILED+=('Persistent Storage: ZFS Dataset not found')
    fi
    
    # make sure its mounted to the container

# TODO: check that its mounted in teh right spot
    _mountFound=$( mount | grep "^${_persistentDataset}" | wc -l  | tr -d '[[:space:]]' )
    
    if [[ ${_mountFound} -eq 1 ]]; then
        _TESTS_PASSED+=('Persistent Storage: ZFS Dataset mounted')
    else
        _TESTS_FAILED+=('Persistent Storage: ZFS Dataset not mounted')
    fi
    
    
fi

# check custom dns
if [[ ${#_CONF_TREDLYFILE_CUSTOMDNS[@]} -gt 0 ]]; then
    if [[ ! -f "${_containerRoot}/etc/resolv.conf" ]]; then
        _TESTS_FAILED+=('resolv.conf: file does not exist')
    else
        for value in "${_CONF_TREDLYFILE_CUSTOMDNS[@]}"
        do
            valueFound=$( cat "${_containerRoot}/etc/resolv.conf" | grep -E "${value}" | wc -l | tr -d '[[:space:]]')
            
            case ${valueFound} in
                0)
                    _TESTS_FAILED+=("resolv.conf: ${value} missing from file")
                    _exitCode=1
                ;;
                1)
                    _TESTS_PASSED+=("resolv.conf: ${value} found once")
                ;;
                *)
                    _TESTS_FAILED+=("resolv.conf: ${value} found ${valueFound} times")
                    _exitCode=1
                ;;
            esac
        done
    fi
fi

e_note "Destroying Container..."
tredly destroy container ${_uuid}

if [[ $? -ne 0 ]]; then
   e_error "Failed to destroy container"
   exit 1
fi

#####################
# POST DESTROY CHECKS
#####################

# check that nginx has been cleaned up
e_header "Checking if NginX files have been removed"

_dir="/usr/local/etc/nginx/access"
_numAccessFiles=$( ls -1 "${_dir}" | wc -l )
if [[ ${_numAccessFiles} -gt 0 ]]; then
    e_error "FAILED: There are remaining access files in ${_dir}"
    ls -l "${_dir}"
    _exitCode=1
    _TESTS_FAILED+=('Filesystem: NginX access files')
else
    e_success "All NginX access files have been cleaned up"
    _TESTS_PASSED+=('Filesystem: NginX access files')
fi
_dir="/usr/local/etc/nginx/upstream"
_numUpstreamFiles=$( ls -1 "${_dir}" | wc -l )
if [[ ${_numUpstreamFiles} -gt 0 ]]; then
    e_error "FAILED: There are remaining upstream files in ${_dir}"
    ls -l "${_dir}"
    _exitCode=1
    _TESTS_FAILED+=('Filesystem: NginX upstream files')
else
    e_success "All NginX upstream files have been cleaned up"
    _TESTS_PASSED+=('Filesystem: NginX upstream files')
fi
_dir="/usr/local/etc/nginx/server_name"
_numServernameFiles=$( ls -1 "${_dir}" | wc -l )
if [[ ${_numServernameFiles} -gt 0 ]]; then
    e_error "FAILED: There are remaining server_name files in ${_dir}"
    ls -l "${_dir}"
    _exitCode=1
    _TESTS_FAILED+=('Filesystem: NginX server_name files')
else
    e_success "All NginX server_name files have been cleaned up"
    _TESTS_PASSED+=('Filesystem: NginX server_name files')
fi

# check that unbound has been cleaned up
e_header "Checking if unbound files have been cleaned up"

_dir="/usr/local/etc/unbound/configs"
_numUnboundFiles=$( ls -1 "${_dir}" | wc -l )
if [[ ${_numUnboundFiles} -gt 0 ]]; then
    e_error "FAILED: There are remaining unbound config files in ${_dir}"
    ls -l "${_dir}"
    _exitCode=1
    _TESTS_FAILED+=('Filesystem: Unbound config files')
else
    e_success "All Unbound config files have been cleaned up"
    _TESTS_PASSED+=('Filesystem: Unbound config files')
fi

e_success "Done"

e_header "Test Results"
echo -e "${_colourGreen}${_formatBold}PASSED TESTS:"
echo -e "----------${_formatReset}${_colourGreen}"

for key in "${!_TESTS_PASSED[@]}"
do
    echo "✔ ${_TESTS_PASSED[${key}]}"
done
echo -e "${_formatReset}"
echo ""

echo -e "${_colourRed}${_formatBold}FAILED TESTS:"
echo -e "----------${_formatReset}${_colourRed}"

for key in "${!_TESTS_FAILED[@]}"
do
    echo "✖ ${_TESTS_FAILED[${key}]}"
done
echo -e "${_formatReset}"
exit ${_exitCode}
