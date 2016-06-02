#!/usr/local/bin/bash

# set some bash error handlers
set -u              # exit when attempting to use an undeclared variable
set -o pipefail     # exit when piped commands fail

# load some bash libraries
_DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# load the common vars
source ${_DIR}/install.vars.sh

# load the libs
for f in ${_DIR}/../lib/common/*.sh; do source ${f}; done
for f in ${_DIR}/../lib/install/*.sh; do source ${f}; done

# make sure this script is running as root
cmn_assert_running_as_root

# get a list of external interfaces
IFS=$'\n' declare -a _externalInterfaces=($( get_external_interfaces ))

# Check if VIMAGE module is loaded
_vimageInstalled=$( sysctl kern.conftxt | grep '^options[[:space:]]VIMAGE$' | wc -l )

###############################
declare -a _configOptions

# check if the install config file exists
if [[ ! -f "${_DIR}/conf/install.conf" ]]; then
    exit_with_error "Could not find conf/install.conf"
fi

# load the config file
_TREDLY_DIR_CONF="${_DIR}/conf"
common_conf_parse "install"

_configOptions[0]=''
# check if some values are set, and if they arent then consult the host for the details
if [[ -z "${_CONF_COMMON[externalInterface]}" ]]; then
    _configOptions[1]="${_externalInterfaces[0]}"
else
    _configOptions[1]="${_CONF_COMMON[externalInterface]}"
fi

if [[ -z "${_CONF_COMMON[externalIP]}" ]]; then
    _configOptions[2]="$( getInterfaceIP "${_externalInterfaces[0]}" )/$( getInterfaceCIDR "${_externalInterfaces[0]}" )"
else
    _configOptions[2]="${_CONF_COMMON[externalIP]}"
fi

if [[ -z "${_CONF_COMMON[externalGateway]}" ]]; then
    _configOptions[3]="$( getDefaultGateway )"
else
    _configOptions[3]="${_CONF_COMMON[externalGateway]}"
fi

if [[ -z "${_CONF_COMMON[hostname]}" ]]; then
    _configOptions[4]="${HOSTNAME}"
else
    _configOptions[4]="${_CONF_COMMON[hostname]}"
fi

if [[ -z "${_CONF_COMMON[containerSubnet]}" ]]; then
    _configOptions[5]="10.99.0.0/16"
else
    _configOptions[5]="${_CONF_COMMON[containerSubnet]}"
fi

if [[ -z "${_CONF_COMMON[apiWhitelist]}" ]]; then
    _configOptions[6]=""
else
    _configOptions[6]="${_CONF_COMMON[apiWhitelist]}"
fi


# check for a dhcp leases file for this interface
#if [[ -f "/var/db/dhclient.leases.${_configOptions[1]}" ]]; then
    # look for its current ip address within the leases file
    #_numLeases=$( grep -E "${DEFAULT_EXT_IP}" "/var/db/dhclient.leases.${_configOptions[1]}" | wc -l )

    #if [[ ${_numLeases} -gt 0 ]]; then
        # found a current lease for this ip address so throw a warning
        #echo -e "${_colourMagenta}=============================================================================="
        #echo -e "${_formatBold}WARNING!${_formatReset}${_colourMagenta} The current IP address ${DEFAULT_EXT_IP} was set using DHCP!"
        #echo "It is recommended that this address be changed to be outside of your DHCP pool"
        #echo -e "==============================================================================${_colourDefault}"
    #fi
#fi

# check if we are doing an unattended installation or not
if [[ "${_CONF_COMMON[unattendedInstall]}" != "yes" ]]; then
    # run the menu
    tredlyHostMenuConfig
fi

# extract the net and cidr from the container subnet we are using
CONTAINER_SUBNET_NET="$( lcut "${_configOptions[5]}" '/')"
CONTAINER_SUBNET_CIDR="$( rcut "${_configOptions[5]}" '/')"
# Get the default host ip address on the private container network
_hostPrivateIP=$( get_last_usable_ip4_in_network "${CONTAINER_SUBNET_NET}" "${CONTAINER_SUBNET_CIDR}" )

####
e_header "Tredly Installation"

##########

# Configure /etc/rc.conf
e_note "Configuring /etc/rc.conf"
_exitCode=0
# rename the existing rc.conf if it exists
if [[ -f "/etc/rc.conf" ]]; then
    mv /etc/rc.conf /etc/rc.conf.old
fi
_exitCode=$(( ${_exitCode} & $? ))
cp ${_DIR}/os/rc.conf /etc/
_exitCode=$(( ${_exitCode} & $? ))
# change the network information in rc.conf
sed -i '' "s|ifconfig_bridge0=.*|ifconfig_bridge0=\"addm ${_configOptions[1]} up\"|g" "/etc/rc.conf"
_exitCode=$(( ${_exitCode} & $? ))
if [[ $? -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# if vimage is installed, enable cloned interfaces
if [[ ${_vimageInstalled} -ne 0 ]]; then
    e_note "Enabling Cloned Interfaces"
    service netif cloneup
    if [[ $? -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi
fi

##########

if [[ -z "${_CONF_COMMON[tredlyApiGit]}" ]]; then
    e_note "Skipping Tredly-API"
else
    # set up tredly api
    e_note "Configuring Tredly-API"
    _exitCode=1
    cd /tmp
    # if the directory for tredly-api already exists, then delete it and start again
    if [[ -d "/tmp/tredly-api" ]]; then
        echo "Cleaning previously downloaded Tredly-API"
        rm -rf /tmp/tredly-api
    fi

    while [[ ${_exitCode} -ne 0 ]]; do
        git clone -b "${_CONF_COMMON[tredlyApiBranch]}" "${_CONF_COMMON[tredlyApiGit]}"
        _exitCode=$?
    done

    cd /tmp/tredly-api
    
    # install the API and extract the random password so we can present this to the user at the end of install
    apiPassword="$( ./install.sh | grep "^Your API password is: " | cut -d':' -f 2 | sed -e 's/^[ \t]*//' )"
    
    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi
fi

##########

# Update FreeBSD and install updates
e_note "Fetching and Installing FreeBSD Updates"
freebsd-update fetch install | tee -a "${_LOGFILE}"
if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# set up pkg
e_note "Configuring PKG"
if [[ -f "/usr/local/etc/pkg.conf" ]]; then
    mv /usr/local/etc/pkg.conf /usr/local/etc/pkg.conf.old
fi
cp ${_DIR}/os/pkg.conf /usr/local/etc/
if [[ $? -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# Install Packages
e_note "Installing Packages"
_exitCode=0
pkg install -y vim-lite | tee -a "${_LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
pkg install -y rsync | tee -a "${_LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
pkg install -y openntpd | tee -a "${_LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
pkg install -y git | tee -a "${_LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
pkg install -y python35 | tee -a "${_LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
if [[ ${_exitCode} -ne 0 ]]; then
    exit_with_error "Failed to download git"
fi
pkg install -y nginx | tee -a "${_LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
if [[ ${_exitCode} -ne 0 ]]; then
    exit_with_error "Failed to download Nginx"
fi
pkg install -y unbound | tee -a "${_LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
if [[ ${_exitCode} -ne 0 ]]; then
    exit_with_error "Failed to download Unbound"
fi
if [[ ${_exitCode} -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# Configure SSH
_exitCode=0
e_note "Configuring SSHD"

if [[ -f "/etc/ssh/sshd_config" ]]; then
    mv /etc/ssh/sshd_config /etc/ssh/sshd_config.old
fi

_exitCode=$(( ${_exitCode} & $? ))
cp ${_DIR}/os/sshd_config /etc/ssh/sshd_config
_exitCode=$(( ${_exitCode} & $? ))
# change the networking data for ssh
sed -i '' "s|ListenAddress .*|ListenAddress ${_configOptions[2]}|g" "/etc/ssh/sshd_config"
_exitCode=$(( ${_exitCode} & $? ))
if [[ ${_exitCode} -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# Configure Vim
e_note "Configuring VIM"
cp ${_DIR}/os/vimrc /usr/local/share/vim/vimrc
if [[ $? -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# Configure IPFW
e_note "Configuring IPFW"
_exitCode=0
mkdir -p /usr/local/etc
_exitCode=$(( ${_exitCode} & $? ))
cp ${_DIR}/os/ipfw.rules /usr/local/etc/ipfw.rules
_exitCode=$(( ${_exitCode} & $? ))
cp ${_DIR}/os/ipfw.layer4 /usr/local/etc/ipfw.layer4
_exitCode=$(( ${_exitCode} & $? ))
cp ${_DIR}/os/ipfw.vars /usr/local/etc/ipfw.vars
_exitCode=$(( ${_exitCode} & $? ))

# Removed ipfw start for now due to its ability to disconnect a user from their host
#service ipfw start
#_exitCode=$(( ${_exitCode} & $? ))
if [[ $_exitCode -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# Configure OpenNTP
_exitCode=0
e_note "Configuring OpenNTP"
if [[ -f "/usr/local/etc/ntpd.conf" ]]; then
    mv /usr/local/etc/ntpd.conf /usr/local/etc/ntpd.conf.old
fi
cp ${_DIR}/os/ntpd.conf /usr/local/etc/
_exitCode=$(( ${_exitCode} & $? ))
if [[ ${_exitCode} -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# Configure zfs scrubbing
#vim /etc/periodic.conf

##########

# Change kernel options
e_note "Configuring kernel options"
_exitCode=0

if [[ -f "/boot/loader.conf" ]]; then
    mv /boot/loader.conf /boot/loader.conf.old
fi
cp ${_DIR}/os/loader.conf /boot/
if [[ $? -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

e_note "Configuring Sysctl"

if [[ -f "/etc/sysctl.conf" ]]; then
    mv /etc/sysctl.conf /etc/sysctl.conf.old
fi
cp ${_DIR}/os/sysctl.conf /etc/
if [[ $? -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# Configure fstab to fix bash bug
if [[ $( grep /dev/fd /etc/fstab | wc -l ) -eq 0 ]]; then
    e_note "Configuring Bash"
    echo "fdesc                   /dev/fd fdescfs rw              0       0" >> /etc/fstab
    if [[ $? -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi
else
   e_note "Bash already configured"
fi

##########

# Configure HTTP Proxy
e_note "Configuring Layer 7 (HTTP) Proxy"
_exitCode=0
mkdir -p /usr/local/etc/nginx/access
_exitCode=$(( ${_exitCode} & $? ))
mkdir -p /usr/local/etc/nginx/server_name
_exitCode=$(( ${_exitCode} & $? ))
mkdir -p /usr/local/etc/nginx/proxy_pass
_exitCode=$(( ${_exitCode} & $? ))
mkdir -p /usr/local/etc/nginx/ssl
_exitCode=$(( ${_exitCode} & $? ))
mkdir -p /usr/local/etc/nginx/upstream
_exitCode=$(( ${_exitCode} & $? ))
cp ${_DIR}/proxy/nginx.conf /usr/local/etc/nginx/
_exitCode=$(( ${_exitCode} & $? ))
cp -R ${_DIR}/proxy/proxy_pass /usr/local/etc/nginx/
_exitCode=$(( ${_exitCode} & $? ))
cp -R ${_DIR}/proxy/tredly_error_docs /usr/local/etc/nginx/
_exitCode=$(( ${_exitCode} & $? ))
if [[ ${_exitCode} -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# Configure Unbound DNS
e_note "Configuring Unbound"
_exitCode=0
mkdir -p /usr/local/etc/unbound/configs
_exitCode=$(( ${_exitCode} & $? ))
cp ${_DIR}/dns/unbound.conf /usr/local/etc/unbound/
_exitCode=$(( ${_exitCode} & $? ))
if [[ ${_exitCode} -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########
_exitCode=0
e_note "Configuring Python"
# install pip
python3.5 -m ensurepip
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
# install jsonschema
pip3 install jsonschema
_exitCode=$(( ${PIPESTATUS[0]} & $? ))

if [[ ${_exitCode} -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# install tredly common libs
e_note "Installing Tredly Common Files"
_exitCode=0

# copy in the bash libs
mkdir -p /usr/local/lib/tredly/common
_exitCode=$(( ${_exitCode} & $? ))
cp -R ${_DIR}/../lib/common/* /usr/local/lib/tredly/common
_exitCode=$(( ${_exitCode} & $? ))

# copy in the config file
mkdir -p /usr/local/etc/tredly
_exitCode=$(( ${_exitCode} & $? ))
cp "${_DIR}/../conf/tredly-host.conf.dist" "/usr/local/etc/tredly/tredly-host.conf"
_exitCode=$(( ${_exitCode} & $? ))

if [[ ${_exitCode} -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########
e_note "Installing Tredly-Core"

# install tredly-core
${_DIR}/../components/tredly/install.sh install clean
if [[ $? -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########
e_note "Installing Tredly-Host"

# install tredly-host
${_DIR}/../components/tredly-host/install.sh install clean
if [[ $? -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# Install tredly-build
e_note "Installing Tredly-Build"

${_DIR}/../components/tredly-build/install.sh install clean
if [[ $? -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

# initialise tredly
tredly-host init

##########

# Setup crontab
e_note "Configuring Crontab"
_exitCode=0
mkdir -p /usr/local/host/
_exitCode=$(( ${_exitCode} & $? ))
cp ${_DIR}/os/crontab /usr/local/host/
_exitCode=$(( ${_exitCode} & $? ))
crontab /usr/local/host/crontab
_exitCode=$(( ${_exitCode} & $? ))
if [[ ${_exitCode} -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

if [[ ${_vimageInstalled} -ne 0 ]]; then
    e_success "Skipping kernel recompile as this kernel appears to already have VIMAGE compiled."
else
    e_note "Recompiling kernel as this kernel does not have VIMAGE built in"

    # lets compile the kernel for VIMAGE!

    # fetch the source if the user said yes or the source doesnt exist
    if [[ "$( str_to_lower "${_CONF_COMMON[downloadKernelSource]}" )" == 'yes' ]] || [[ ! -d '/usr/src/sys' ]]; then
        _thisRelease=$( sysctl -n kern.osrelease | cut -d '-' -f 1 -f 2 )
        
        # download manifest file to validate src.txz
        fetch http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/${_thisRelease}/MANIFEST -o /tmp
        
        # if we have downlaoded src.txz for tredly then use that
        if [[ -f /tredly/downloads/${_thisRelease}/src.txz ]]; then
            e_note "Copying pre-downloaded src.txz"
            
            cp /tredly/downloads/${_thisRelease}/src.txz /tmp
        else
            # otherwise download the src file
            fetch http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/${_thisRelease}/src.txz -o /tmp
        fi
        
        # validate src.txz against MANIFEST
        _upstreamHash=$( cat /tmp/MANIFEST | grep ^src.txz | awk -F" " '{ print $2 }' )
        _localHash=$( sha256 -q /tmp/src.txz )

        if [[ "${_upstreamHash}" != "${_localHash}" ]]; then
            # remove it as it is of no use to us
            rm -f /tmp/src.txz
            # exit and print error
            exit_with_error "Validation failed on src.txz. Please try installing again."
        else
            e_success "Validation passed for src.txz"
        fi
        
        if [[ $? -ne 0 ]]; then
            exit_with_error "Failed to download src.txz"
        fi

        # move the old source to another dir if it already exists
        if [[ -d "/usr/src/sys" ]]; then
            # clean up the old source
            mv /usr/src/sys /usr/src/sys.`date +%s`
        fi

        # unpack new source
        tar -C / -xzf /tmp/src.txz
        if [[ $? -ne 0 ]]; then
            exit_with_error "Failed to unpack src.txz"
        fi
    fi
    
    cd /usr/src
    
    # clean up any previously failed builds
    if [[ $( ls -1 /usr/obj | wc -l ) -gt 0 ]]; then
        e_note "Cleaning previously compiled Kernel"
        chflags -R noschg /usr/obj/usr >> "${_KERNELCOMPILELOG}"
        rm -rf /usr/obj/usr >> "${_KERNELCOMPILELOG}"
        make cleandir >> "${_KERNELCOMPILELOG}"
        make cleandir >> "${_KERNELCOMPILELOG}"
    fi

    # copy in the tredly kernel configuration file
    cp ${_DIR}/kernel/TREDLY /usr/src/sys/amd64/conf

    # work out how many cpus are available to this machine, and use 80% of them to speed up compile
    _availCpus=$( sysctl -n hw.ncpu )
    _useCpus=$( echo "scale=2; ${_availCpus}*0.8" | bc | cut -d'.' -f 1 )

    # if we have a value less than 1 then set it to 1
    if [[ ${_useCpus} -lt 1 ]]; then
        _useCpus=1
    fi

    e_note "Compiling kernel using ${_useCpus} CPUs..."
    e_note "This may take some time..."
    make -j${_useCpus} buildkernel KERNCONF=TREDLY >> "${_KERNELCOMPILELOG}"

    # only install the kernel if the build succeeded
    if [[ $? -eq 0 ]]; then
        e_note "Installing New Kernel"
        make installkernel KERNCONF=TREDLY >> "${_KERNELCOMPILELOG}"
        
        if [[ $? -ne 0 ]]; then
            exit_with_error "Failed to install kernel"
        fi
    else
        exit_with_error "Failed to build kernel"
    fi
fi

# delete the src.txz file from /tmp to save on space
if [[ -f "/tmp/src.txz" ]]; then
    rm -f /tmp/src.txz
fi

##########

# use tredly to set network details
tredly-host config host network "${_configOptions[1]}" "${_configOptions[2]}" "${_configOptions[3]}"

tredly-host config host hostname "${_configOptions[4]}"

tredly-host config container subnet "${_configOptions[5]}"


# if whitelist was given to us then set it up
if [[ -n "${_CONF_COMMON[apiWhitelist]}" ]]; then
    e_note "Whitelisting IP addresses for API"
    # clear the whitelist in case of old entries
    tredly-host config firewall clearAPIwhitelist > /dev/null
    
    declare -a _whitelistArray
    IFS=',' read -ra _whitelistArray <<< "${_CONF_COMMON[apiWhitelist]}"
    
    _exitCode=0
    for ip in ${_whitelistArray[@]}; do
        tredly-host config firewall addAPIwhitelist "${ip}" > /dev/null
        _exitCode=$(( ${_exitCode} & $? ))
    done
    
    if [[ ${_exitCode} -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi
fi


# echo out confirmation message to user
e_header "Install Complete"
echo -e "${_colourOrange}${_formatBold}"
echo "**************************************"
echo "Your API Password is: ${apiPassword}"
echo -e "**************************************${_formatReset}"
echo -e "${_colourMagenta}"
echo "Please make note of this password so that you may access the API"
echo ""
#echo "To change this password, please run the command 'tredly-host config api password'"
echo "To whitelist addresses to access the API, please run the command 'tredly-host config firewall addAPIwhitelist <ip address>'"
echo ""
echo -e "Please ${_formatBold}REBOOT${_formatReset}${_colourMagenta} your host for the new kernel and settings to take effect."
echo ""
echo "Please note that the SSH port has changed, use the following to connect to your host after reboot:"
echo "ssh -p 65222 tredly@$( lcut "${_configOptions[2]}" "/" )"
echo -e "${_formatReset}"