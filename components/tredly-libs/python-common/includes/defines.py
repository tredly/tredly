# GLOBALS USED BY TREDLY
# These are constant and will not change throughout execution
# define globals
global ZFS_ROOT
global ZFS_TREDLY_DATASET
global ZFS_TREDLY_CONTAINER_DATASET
global ZFS_TREDLY_DOWNLOADS_DATASET
global ZFS_TREDLY_LOG_DATASET
global ZFS_TREDLY_PARTITIONS_DATASET
global ZFS_TREDLY_PERSISTENT_DATASET
global ZFS_TREDLY_RELEASES_DATASET
global TREDLY_MOUNT
global TREDLY_CONTAINER_MOUNT
global TREDLY_DOWNLOADS_MOUNT
global TREDLY_LOG_MOUNT
global TREDLY_PARTITIONS_MOUNT
global TREDLY_PERSISTENT_MOUNT
global TREDLY_RELEASES_MOUNT
global ZFS_PROP_ROOT
global TREDLY_DEFAULT_PARTITION
global TREDLY_CONTAINER_DIR_NAME
global TREDLY_PTN_DATA_DIR_NAME
global TREDLY_PTN_REMOTECONTAINERS_DIR_NAME
global NGINX_BASE_DIR
global NGINX_UPSTREAM_DIR
global NGINX_SERVERNAME_DIR
global NGINX_SSLCONFIG_DIR
global NGINX_ACCESSFILE_DIR
global UNBOUND_ETC_DIR
global UNBOUND_CONFIG_DIR
global TREDLY_ONSTOP_SCRIPT
global IPFW_SCRIPT
global IPFW_FORWARDS
global IPFW_TABLE_PUBLIC_IPS
global IPFW_TABLE_PUBLIC_EPAIRS
global CONTAINER_IPFW_SCRIPT
global CONTAINER_IPFW_PARTITION_SCRIPT
global CONTAINER_IPFW_WL_TABLE_CONTAINERGROUP
global CONTAINER_IPFW_WL_TABLE_PARTITION
global CONTAINER_IPFW_WL_TABLE_CONTAINER
global VNET_CONTAINER_IFACE_NAME
global RELEASES_SUPPORTED
global CONTAINER_BASEDIRS
global VALID_TECHNICAL_OPTIONS
global CONTAINER_OPTIONS
global CONTAINER_CREATE_DIRS

global VERSON_NUMBER
global VERSION_DATE

# set version/date
VERSION_NUMBER = "1.0.2"
VERSION_DATE = "June 27 2016"

# ZFS Dataset locations
ZFS_ROOT = "zroot"
ZFS_TREDLY_DATASET = ZFS_ROOT + "/tredly"
ZFS_TREDLY_DOWNLOADS_DATASET = ZFS_TREDLY_DATASET + "/downloads"
ZFS_TREDLY_LOG_DATASET = ZFS_TREDLY_DATASET + "/log"
ZFS_TREDLY_PARTITIONS_DATASET = ZFS_TREDLY_DATASET + "/ptn"
ZFS_TREDLY_RELEASES_DATASET = ZFS_TREDLY_DATASET + "/releases"

# ZFS Mount locations
TREDLY_MOUNT = "/tredly"
TREDLY_DOWNLOADS_MOUNT = TREDLY_MOUNT + "/downloads"
TREDLY_LOG_MOUNT = TREDLY_MOUNT + "/log"
TREDLY_PARTITIONS_MOUNT = TREDLY_MOUNT + "/ptn"
TREDLY_RELEASES_MOUNT = TREDLY_MOUNT + "/releases"

# zfs properties
ZFS_PROP_ROOT = "com.tredly"

# name of the default partition within ZFS_TREDLY_PARTITIONS_DATASET/ TREDLY_PARTITIONS_MOUNT
TREDLY_DEFAULT_PARTITION = "default"
TREDLY_CONTAINER_DIR_NAME = "cntr"
TREDLY_PTN_DATA_DIR_NAME = "data"
TREDLY_PERSISTENT_STORAGE_DIR_NAME = "psnt"
TREDLY_CONTAINER_LOG_DIR = "log"
TREDLY_PTN_REMOTECONTAINERS_DIR_NAME="remotecontainers"

# Nginx Proxy
NGINX_BASE_DIR = "/usr/local/etc/nginx"
NGINX_UPSTREAM_DIR = NGINX_BASE_DIR + "/upstream"
NGINX_SERVERNAME_DIR = NGINX_BASE_DIR + "/server_name"
NGINX_SSL_DIR = NGINX_BASE_DIR + "/ssl"
NGINX_ACCESSFILE_DIR = NGINX_BASE_DIR + "/access"

# Unbound
UNBOUND_ETC_DIR = "/usr/local/etc/unbound"
UNBOUND_CONFIG_DIR = "/usr/local/etc/unbound/configs"

# Tredly onstop script
TREDLY_ONSTOP_SCRIPT = "/etc/rc.onstop"

# IPFW Scripts
IPFW_SCRIPT = "/usr/local/etc/ipfw.rules"
IPFW_FORWARDS = "/usr/local/etc/ipfw.layer4"

# The table numbers within the host
IPFW_TABLE_PUBLIC_IPS = "1"
IPFW_TABLE_PUBLIC_EPAIRS = "2"

# Main IPFW rules within containers
CONTAINER_IPFW_SCRIPT = "/usr/local/etc/ipfw.rules"
CONTAINER_IPFW_PARTITION_SCRIPT = "/usr/local/etc/ipfw.partition"

# the table numbers within the container for each whitelist
CONTAINER_IPFW_WL_TABLE_CONTAINERGROUP = "1"
CONTAINER_IPFW_WL_TABLE_PARTITION = "2"
CONTAINER_IPFW_WL_TABLE_CONTAINER = "3"

## what to rename the interface to within the container
VNET_CONTAINER_IFACE_NAME = "vnet0"

# Supported FreeBSD Releases
RELEASES_SUPPORTED = []
RELEASES_SUPPORTED.append('10.3-RELEASE')

# Default container options
CONTAINER_OPTIONS={}
CONTAINER_OPTIONS['securelevel'] = "2"
CONTAINER_OPTIONS['devfs_ruleset'] = "4"
CONTAINER_OPTIONS['enforce_statfs'] = "2"
CONTAINER_OPTIONS['children.max'] = "0"
CONTAINER_OPTIONS['allow.set_hostname'] = "0"
CONTAINER_OPTIONS['allow.sysvipc'] = "0"
CONTAINER_OPTIONS['allow.raw_sockets'] = "0"
CONTAINER_OPTIONS['allow.chflags'] = "0"
CONTAINER_OPTIONS['allow.mount'] = "0"
CONTAINER_OPTIONS['allow.mount.devfs'] = "0"
CONTAINER_OPTIONS['allow.mount.nullfs'] = "0"
CONTAINER_OPTIONS['allow.mount.procfs'] = "0"
CONTAINER_OPTIONS['allow.mount.tmpfs'] = "0"
CONTAINER_OPTIONS['allow.mount.zfs'] = "0"
CONTAINER_OPTIONS['allow.quotas'] = "0"
CONTAINER_OPTIONS['allow.socket_af'] = "0"
CONTAINER_OPTIONS['exec.prestart'] = "/usr/bin/true"
CONTAINER_OPTIONS['exec.poststart'] = "/usr/bin/true"
CONTAINER_OPTIONS['exec.prestop'] = "/usr/bin/true"
CONTAINER_OPTIONS['exec.start'] = "/bin/sh /etc/rc"
CONTAINER_OPTIONS['exec.stop'] = "/bin/sh /etc/rc.shutdown"
CONTAINER_OPTIONS['exec.clean'] = "1"
CONTAINER_OPTIONS['exec.timeout'] = "60"
CONTAINER_OPTIONS['exec.fib'] = "0"
CONTAINER_OPTIONS['stop.timeout'] = "30"
CONTAINER_OPTIONS['mount.devfs'] = "0"
CONTAINER_OPTIONS['mount.fdescfs'] = "1"
CONTAINER_OPTIONS['ip4'] = "new"
CONTAINER_OPTIONS['ip4_saddrsel'] = "1"

# default dirs to create within a container
CONTAINER_CREATE_DIRS = []
CONTAINER_CREATE_DIRS.append('/bin')
CONTAINER_CREATE_DIRS.append('/boot')
CONTAINER_CREATE_DIRS.append('/compat')
CONTAINER_CREATE_DIRS.append('/etc')
CONTAINER_CREATE_DIRS.append('/etcupdate')
CONTAINER_CREATE_DIRS.append('/dev')
CONTAINER_CREATE_DIRS.append('/lib')
CONTAINER_CREATE_DIRS.append('/libexec')
CONTAINER_CREATE_DIRS.append('/mnt')
CONTAINER_CREATE_DIRS.append('/proc')
CONTAINER_CREATE_DIRS.append('/rescue')
CONTAINER_CREATE_DIRS.append('/root')
CONTAINER_CREATE_DIRS.append('/sbin')
CONTAINER_CREATE_DIRS.append('/tmp')
CONTAINER_CREATE_DIRS.append('/usr/bin')
CONTAINER_CREATE_DIRS.append('/usr/include')
CONTAINER_CREATE_DIRS.append('/usr/lib')
CONTAINER_CREATE_DIRS.append('/usr/lib32')
CONTAINER_CREATE_DIRS.append('/usr/libdata')
CONTAINER_CREATE_DIRS.append('/usr/libexec')
CONTAINER_CREATE_DIRS.append('/usr/local/etc')
CONTAINER_CREATE_DIRS.append('/usr/obj')
CONTAINER_CREATE_DIRS.append('/usr/ports')
CONTAINER_CREATE_DIRS.append('/usr/sbin')
CONTAINER_CREATE_DIRS.append('/usr/share')
CONTAINER_CREATE_DIRS.append('/usr/src')
CONTAINER_CREATE_DIRS.append('/var')
CONTAINER_CREATE_DIRS.append('/var/cache/pkg')
CONTAINER_CREATE_DIRS.append('/var/db/pkg')
CONTAINER_CREATE_DIRS.append('/var/empty')
CONTAINER_CREATE_DIRS.append('/var/log')
CONTAINER_CREATE_DIRS.append('/var/ports')
CONTAINER_CREATE_DIRS.append('/var/ports/distfiles')
CONTAINER_CREATE_DIRS.append('/var/ports/packages')
CONTAINER_CREATE_DIRS.append('/var/run')
CONTAINER_CREATE_DIRS.append('/var/tmp')

# some files to create on container creation
CONTAINER_CREATE_FILES = []
CONTAINER_CREATE_FILES.append("/etc/fstab")

# some directories to copy from the release
CONTAINER_COPY_DIRS = []
CONTAINER_COPY_DIRS.append('/etc')
CONTAINER_COPY_DIRS.append('/root')

# files to copy from the host
CONTAINER_COPY_HOST_FILES = []
CONTAINER_COPY_HOST_FILES.append('/etc/localtime')
CONTAINER_COPY_HOST_FILES.append('/etc/resolv.conf')

# Base directories for container to mount from release
CONTAINER_BASEDIRS = []
CONTAINER_BASEDIRS.append('/bin')
CONTAINER_BASEDIRS.append('/boot')
CONTAINER_BASEDIRS.append('/lib')
CONTAINER_BASEDIRS.append('/libexec')
CONTAINER_BASEDIRS.append('/rescue')
CONTAINER_BASEDIRS.append('/sbin')
CONTAINER_BASEDIRS.append('/usr/bin')
CONTAINER_BASEDIRS.append('/usr/include')
CONTAINER_BASEDIRS.append('/usr/lib')
CONTAINER_BASEDIRS.append('/usr/libexec')
CONTAINER_BASEDIRS.append('/usr/ports')
CONTAINER_BASEDIRS.append('/usr/sbin')
CONTAINER_BASEDIRS.append('/usr/share')
CONTAINER_BASEDIRS.append('/usr/src')
CONTAINER_BASEDIRS.append('/usr/libdata')
CONTAINER_BASEDIRS.append('/usr/lib32')