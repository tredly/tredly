#!/usr/bin/env bash

# success/failure return codes
declare E_SUCCESS=0
declare E_ERROR=1
declare E_FATAL=2

# verbose mode
declare _VERBOSE_MODE=false

# ZFS Dataset locations
declare ZFS_ROOT="zroot"
declare ZFS_TREDLY_DATASET="${ZFS_ROOT}/tredly"
declare ZFS_TREDLY_CONTAINER_DATASET="${ZFS_TREDLY_DATASET}/containers"
declare ZFS_TREDLY_DOWNLOADS_DATASET="${ZFS_TREDLY_DATASET}/downloads"
declare ZFS_TREDLY_LOG_DATASET="${ZFS_TREDLY_DATASET}/log"
declare ZFS_TREDLY_PARTITIONS_DATASET="${ZFS_TREDLY_DATASET}/ptn"
declare ZFS_TREDLY_PERSISTENT_DATASET="${ZFS_TREDLY_DATASET}/persistent"
declare ZFS_TREDLY_RELEASES_DATASET="${ZFS_TREDLY_DATASET}/releases"

# ZFS Mount locations
declare TREDLY_MOUNT="/tredly"
declare TREDLY_CONTAINER_MOUNT="${TREDLY_MOUNT}/containers"
declare TREDLY_DOWNLOADS_MOUNT="${TREDLY_MOUNT}/downloads"
declare TREDLY_LOG_MOUNT="${TREDLY_MOUNT}/log"
declare TREDLY_PARTITIONS_MOUNT="${TREDLY_MOUNT}/ptn"
declare TREDLY_PERSISTENT_MOUNT="${TREDLY_MOUNT}/persistent"
declare TREDLY_RELEASES_MOUNT="${TREDLY_MOUNT}/releases"

# zfs properties
declare ZFS_PROP_ROOT="com.tredly"

# name of the default partition within ZFS_TREDLY_PARTITIONS_DATASET/TREDLY_PARTITIONS_MOUNT
declare TREDLY_DEFAULT_PARTITION="default"
declare TREDLY_CONTAINER_DIR_NAME="cntr"
declare TREDLY_PTN_DATA_DIR_NAME="data"

# Nginx Proxy
declare NGINX_BASE_DIR="/usr/local/etc/nginx"
declare NGINX_UPSTREAM_DIR="${NGINX_BASE_DIR}/upstream"
declare NGINX_SERVERNAME_DIR="${NGINX_BASE_DIR}/server_name"
declare NGINX_SSL_DIR="${NGINX_BASE_DIR}/ssl"
declare NGINX_SSLCONFIG_DIR="${NGINX_BASE_DIR}/sslconfig"
declare NGINX_ACCESSFILE_DIR="${NGINX_BASE_DIR}/access"

# Unbound
declare UNBOUND_ETC_DIR="/usr/local/etc/unbound"
declare UNBOUND_CONFIG_DIR="/usr/local/etc/unbound/configs"

# Tredly onstop script
declare TREDLY_ONSTOP_SCRIPT="/etc/rc.onstop"

# IPFW Scripts
declare IPFW_SCRIPT="/usr/local/etc/ipfw.rules"
declare IPFW_FORWARDS="/usr/local/etc/ipfw.layer4"
declare IPFW_VARS="/usr/local/etc/ipfw.vars"

# The table numbers within the host
declare IPFW_TABLE_PUBLIC_IPS="1"
declare IPFW_TABLE_PUBLIC_EPAIRS="2"

# Main IPFW rules within containers
declare CONTAINER_IPFW_SCRIPT="/usr/local/etc/ipfw.rules"
declare CONTAINER_IPFW_PARTITION_SCRIPT="/usr/local/etc/ipfw.partition"

# the table numbers within the container for each whitelist
declare CONTAINER_IPFW_WL_TABLE_CONTAINERGROUP="1"
declare CONTAINER_IPFW_WL_TABLE_PARTITION="2"
declare CONTAINER_IPFW_WL_TABLE_CONTAINER="3"

# location of rc.conf
declare RC_CONF="/etc/rc.conf"

# location of sshd_config
declare SSHD_CONFIG="/etc/ssh/sshd_config"

## what to rename the interface to within the container
declare VNET_CONTAINER_IFACE_NAME="vnet0"

# Supported FreeBSD Releases
declare -a RELEASES_SUPPORTED
RELEASES_SUPPORTED+=('10.3-RELEASE')

# Base directories for container
declare -a BASEDIRS
BASEDIRS+=('bin')
BASEDIRS+=('boot')
BASEDIRS+=('lib')
BASEDIRS+=('libexec')
BASEDIRS+=('rescue')
BASEDIRS+=('sbin')
BASEDIRS+=('usr/bin')
BASEDIRS+=('usr/include')
BASEDIRS+=('usr/lib')
BASEDIRS+=('usr/libexec')
BASEDIRS+=('usr/ports')
BASEDIRS+=('usr/sbin')
BASEDIRS+=('usr/share')
BASEDIRS+=('usr/src')
BASEDIRS+=('usr/libdata')
BASEDIRS+=('usr/lib32')

# provide a list of technicaloptions which we will accept from the Tredlyfile
declare -a VALID_TECHNICAL_OPTIONS

VALID_TECHNICAL_OPTIONS+=('securelevel')
VALID_TECHNICAL_OPTIONS+=('devfs_ruleset')
VALID_TECHNICAL_OPTIONS+=('enforce_statfs')
VALID_TECHNICAL_OPTIONS+=('children_max')
VALID_TECHNICAL_OPTIONS+=('allow_set_hostname')
VALID_TECHNICAL_OPTIONS+=('allow_sysvipc')
VALID_TECHNICAL_OPTIONS+=('allow_raw_sockets')
VALID_TECHNICAL_OPTIONS+=('allow_chflags')
VALID_TECHNICAL_OPTIONS+=('allow_mount')
VALID_TECHNICAL_OPTIONS+=('allow_mount_devfs')
VALID_TECHNICAL_OPTIONS+=('allow_mount_nullfs')
VALID_TECHNICAL_OPTIONS+=('allow_mount_procfs')
VALID_TECHNICAL_OPTIONS+=('allow_mount_tmpfs')
VALID_TECHNICAL_OPTIONS+=('allow_mount_zfs')
VALID_TECHNICAL_OPTIONS+=('allow_quotas')
VALID_TECHNICAL_OPTIONS+=('allow_socket_af')
VALID_TECHNICAL_OPTIONS+=('exec_prestart')
VALID_TECHNICAL_OPTIONS+=('exec_poststart')
VALID_TECHNICAL_OPTIONS+=('exec_prestop')
VALID_TECHNICAL_OPTIONS+=('exec_stop')
VALID_TECHNICAL_OPTIONS+=('exec_clean')
VALID_TECHNICAL_OPTIONS+=('exec_timeout')
VALID_TECHNICAL_OPTIONS+=('exec_fib')
VALID_TECHNICAL_OPTIONS+=('stop_timeout')
VALID_TECHNICAL_OPTIONS+=('mount_devfs')
VALID_TECHNICAL_OPTIONS+=('mount_fdescfs')
