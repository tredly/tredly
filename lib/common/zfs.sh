#!/usr/bin/env bash

# Checks that ZFS is installed
function check_for_zfs() {
    if [[ $( kldstat | grep 'zfs.ko$' | wc -l ) -eq 0 ]]; then
        exit_with_error "ZFS is not loaded!"
    fi
}

# Creates all ZFS datasets necessary for tredly-build to function
function zfs_init() {
    # initialise the zfs datasets ready for use by tredly
    e_verbose "Initialising ZFS Datasets"

    # only create datasets if they dont already exist
    if [[ $( zfs list "${ZFS_TREDLY_DATASET}" 2> /dev/null | wc -l ) -eq 0 ]]; then
        e_verbose "Creating ${ZFS_TREDLY_DATASET}"
        zfs_create_dataset "${ZFS_TREDLY_DATASET}" "${TREDLY_MOUNT}"
    fi
    if [[ $( zfs list "${ZFS_TREDLY_DOWNLOADS_DATASET}" 2> /dev/null | wc -l ) -eq 0 ]]; then
        e_verbose "Creating ${ZFS_TREDLY_DOWNLOADS_DATASET}"
        zfs_create_dataset "${ZFS_TREDLY_DOWNLOADS_DATASET}" "${TREDLY_DOWNLOADS_MOUNT}"
    fi
    if [[ $( zfs list "${ZFS_TREDLY_PERSISTENT_DATASET}" 2> /dev/null | wc -l ) -eq 0 ]]; then
        e_verbose "Creating ${ZFS_TREDLY_PERSISTENT_DATASET}"
        zfs_create_dataset "${ZFS_TREDLY_PERSISTENT_DATASET}" "${TREDLY_PERSISTENT_MOUNT}"
    fi
    if [[ $( zfs list "${ZFS_TREDLY_RELEASES_DATASET}" 2> /dev/null | wc -l ) -eq 0 ]]; then
        e_verbose "Creating ${ZFS_TREDLY_RELEASES_DATASET}"
        zfs_create_dataset "${ZFS_TREDLY_RELEASES_DATASET}" "${TREDLY_RELEASES_MOUNT}"
    fi
    if [[ $( zfs list "${ZFS_TREDLY_LOG_DATASET}" 2> /dev/null | wc -l ) -eq 0 ]]; then
        e_verbose "Creating ${ZFS_TREDLY_LOG_DATASET}"
        zfs_create_dataset "${ZFS_TREDLY_LOG_DATASET}" "${TREDLY_LOG_MOUNT}"
    fi

    # create the partitions dataset
    if [[ $( zfs list "${ZFS_TREDLY_PARTITIONS_DATASET}" 2> /dev/null | wc -l ) -eq 0 ]]; then
        e_verbose "Creating ${ZFS_TREDLY_PARTITIONS_DATASET}"
        zfs_create_dataset "${ZFS_TREDLY_PARTITIONS_DATASET}" "${TREDLY_PARTITIONS_MOUNT}"
    fi

    # create a default partition under the partitions dataset
    if [[ $( zfs list "${ZFS_TREDLY_PARTITIONS_DATASET}/${TREDLY_DEFAULT_PARTITION}" 2> /dev/null | wc -l ) -eq 0 ]]; then
        partition_create "${TREDLY_DEFAULT_PARTITION}" "" "" "" "true"
    fi
}

# gets a zfs property
# args:
# datasetname, property name
# returns: value
function zfs_get_property() {
    # get the value from ZFS dataset
    local value=$(zfs get -H -o value "${2}" "${1}" 2> /dev/null)

    if [[ $? -eq 0 ]]; then
        echo "${value}"
        return ${E_SUCCESS}
    fi

    return ${E_ERROR}
}

# returns a newline separated list of values from the zfs dataset in the correct order
function zfs_get_custom_array() {
    local _dataset="${1}"
    local _property="${2}"

    # get the data
    local _existing=$( zfs get -H -o property,value all "${_dataset}" | grep "^${_property}:" | sort -k 1 -n )
    if [[ -n "${_existing}" ]]; then
        echo "${_existing}" | awk '{print $2}'
    else
        echo ""
    fi
}

# appends a value to a zfs property "array"
function zfs_append_custom_array() {
    local _dataset="${1}"
    local _property="${2}"
    local _value="${3}"
    local _ifNotExists="${4}"

    if [[ -z "${_ifNotExists}" ]]; then
        _ifNotExists="false"
    fi

    local i=0
    # make sure we have a value to set
    if [[ -z "${_value}" ]]; then
        return ${E_ERROR}
    fi

    # check any properties are set
    local _existing=$( zfs get -H -o property,value all "${_dataset}" | grep "${_property}" | sed "s/^${_property}://" | sort -k 1 -n )
    if [[ -n "${_existing}" ]]; then
        if [[ "${_ifNotExists}" == "true" ]]; then
            # check if it exists
            local _exists=$( echo "${_existing}" | awk '{print $2}' | grep "${_value}" | wc -l )

            # if it exists then return
            if [[ ${_exists} -gt 0 ]]; then
                return ${E_SUCCESS}
            fi
        fi

        # get the index of the last item
        local i=$( echo "${_existing}" | tail -1 | awk '{print $1}' | cut -d : -f 2 )

        i=$(( ${i} + 1 ))
    else
        i=0
    fi
    # set the property
    zfs set "${_property}:${i}=${_value}" ${_dataset}

    return $?
}

# unsets an array within zfs
function zfs_unset_custom_array() {
    local _dataset="${1}"
    local _property="${2}"

    # get the data
    local _existing=$( zfs get -H -o property,value all "${_dataset}" | grep "${_property}" | sed "s/^${_property}://" | sort -k 1 -n )
    local _maxIndex=0

    if [[ -n "${_existing}" ]]; then
        _maxIndex=$( echo "${_existing}" | tail -1 | awk '{print $1}' | cut -d : -f 2 )

        # loop over the indexes, unsetting them
        for i in `seq 0 ${_maxIndex}`; do
            zfs inherit -r "${_property}:${i}" "${_dataset}"
        done
    fi

}

# sets a zfs property
# args:
# datasetname, property name, value
function zfs_set_property() {
    local _dataset="${1}"
    local _property="${2}"
    local _value="${3}"

    # make sure we have a value to set
    if [[ -z "${_value}" ]]; then
        return ${E_ERROR}
    fi

    # set the property
    zfs set "${_property}=${_value}" ${_dataset}

    local _exitCode=$?

    return ${_exitCode}
}

# Creates a zfs dataset
function zfs_create_dataset() {
    local _dataSet="${1}"
    local _mountPoint="${2}"

    # first check that the dataset doesnt already exist
    _datasetLines=$( zfs list | grep "^${_dataSet} " | wc -l )
    if [[ ${_datasetLines} -gt 0 ]]; then
        return ${E_ERROR}
    fi

    # create the zfs dataset and mount it
    zfs create -pu -o mountpoint="${_mountPoint}" "${_dataSet}"
    local _createExitCode=$?

    if [[ ${_createExitCode} -ne 0 ]]; then
        return ${E_ERROR}
    fi

    # now mount it
    zfs mount "${_dataSet}"
    local _mountExitCode=$?

    if [[ ${_mountExitCode} -ne 0 ]]; then
        return ${E_ERROR}
    fi

    return ${E_SUCCESS}
}

# destroys a ZFS dataset
function zfs_destroy_dataset() {
    local _dataset="${1}"

    zfs destroy "${_dataset}"

    return $?
}

# mounts a zfs nullfs mount inside a container
function zfs_mount_nullfs_in_jail() {
    local _dataSet="${1}"
    local _mountPoint="${2}"

    # create the directory for persistent storage within the container
    mkdir -p "${_mountPoint}"

    # get the hosts mountpoint
    local _hostMountPoint=$( zfs get -H -o value mountpoint "${_dataSet}" )

    # now mount it to the container using nullfs
    mount -t nullfs "${_hostMountPoint}" "${_mountPoint}"

    if [[ $? -ne 0 ]]; then
        return ${E_ERROR}
    fi

    return ${E_SUCCESS}
}

# detaches a zfs nullfs mount from a given JID
function zfs_unmount_nullfs_in_jail() {
    local _mountPoint="${1}"

    # unmount it from the container
    umount -f "${_mountPoint}"

    if [[ $? -ne 0 ]]; then
        return ${E_ERROR}
    fi

    return ${E_SUCCESS}
}

# lists out all container datasets
# args - partitionname
function zfs_get_all_containers() {
    local _partitionName="${1}"

    # if no partition name was passed, then list all partitions
    if [[ -z "${_partitionName}" ]]; then
        local _partitions=$( get_partition_names )

        IFS=$'\n'
        for _partitionName in ${_partitions}; do
            zfs list -d3 -rH -o name ${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}  | grep -Ev "${TREDLY_CONTAINER_DIR_NAME}\$|*./root"
            _datasets=$( echo -e "${_datasets}\n${_partitionDS}" )
        done

    else
        zfs list -d3 -rH -o name ${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}  | grep -Ev "${TREDLY_CONTAINER_DIR_NAME}\$|*./root"
    fi
}

# creates a zfs container
function zfs_create_container() {
    local _containerName="${1}"
    local _partitionName="${2}"
    local _releaseName="${3}"

    # make sure the release exists
    if [[ ! -d "${TREDLY_RELEASES_MOUNT}/${_releaseName}" ]]; then
        return ${E_FATAL}
    fi

    # generate a 8 byte uuid for this container
    local _uuid=$( generate_short_uuid )

    # loop until we get a uuid that doesnt exist
    while container_exists "${_uuid}"; do
        _uuid=$( generate_short_uuid )
    done

    local _containerDataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${_uuid}"
    local _containerMount="${TREDLY_PARTITIONS_MOUNT}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${_uuid}"

    # create the dataset for this container
    zfs_create_dataset "${_containerDataset}" "${_containerMount}"

    # create default files/folders
    mkdir -p "${_containerMount}/root/bin"
    mkdir -p "${_containerMount}/root/boot"
    mkdir -p "${_containerMount}/root/compat"
    mkdir -p "${_containerMount}/root/etc"
    mkdir -p "${_containerMount}/root/etcupdate"
    mkdir -p "${_containerMount}/root/dev"
    mkdir -p "${_containerMount}/root/lib"
    mkdir -p "${_containerMount}/root/libexec"
    mkdir -p "${_containerMount}/root/mnt"
    mkdir -p "${_containerMount}/root/proc"
    mkdir -p "${_containerMount}/root/rescue"
    mkdir -p "${_containerMount}/root/root"
    mkdir -p "${_containerMount}/root/sbin"
    mkdir -p "${_containerMount}/root/tmp"
    mkdir -p "${_containerMount}/root/usr/bin"
    mkdir -p "${_containerMount}/root/usr/include"
    mkdir -p "${_containerMount}/root/usr/lib"
    mkdir -p "${_containerMount}/root/usr/lib32"
    mkdir -p "${_containerMount}/root/usr/libdata"
    mkdir -p "${_containerMount}/root/usr/libexec"
    mkdir -p "${_containerMount}/root/usr/local/etc"
    mkdir -p "${_containerMount}/root/usr/obj"
    mkdir -p "${_containerMount}/root/usr/ports"
    mkdir -p "${_containerMount}/root/usr/sbin"
    mkdir -p "${_containerMount}/root/usr/share"
    mkdir -p "${_containerMount}/root/usr/src"
    mkdir -p "${_containerMount}/root/var"
    mkdir -p "${_containerMount}/root/var/cache/pkg"
    mkdir -p "${_containerMount}/root/var/db/pkg"
    mkdir -p "${_containerMount}/root/var/empty"
    mkdir -p "${_containerMount}/root/var/log"
    mkdir -p "${_containerMount}/root/var/ports"
    mkdir -p "${_containerMount}/root/var/ports/distfiles"
    mkdir -p "${_containerMount}/root/var/ports/packages"
    mkdir -p "${_containerMount}/root/var/run"
    mkdir -p "${_containerMount}/root/var/tmp"
    touch "${_containerMount}/root/fstab"

    # mount basedirs
    e_verbose "Mounting base dirs"
    if ! zfs_mount_basedirs "${_partitionName}" "${_uuid}" "${_releaseName}"; then
        exit_with_error "Failed to mount base dirs for container ${_uuid}"
    fi

    # copy some useful directories in
    cd ${TREDLY_RELEASES_MOUNT}/${_releaseName}/root/etc && find . | cpio -dp --quiet ${_containerMount}/root/etc
    cd ${TREDLY_RELEASES_MOUNT}/${_releaseName}/root/root && find . | cpio -dp --quiet ${_containerMount}/root/root

    # copy localtime in too if it exists
    if [ -e "/etc/localtime" ] ; then
        cp /etc/localtime ${_containerMount}/root/etc/
    fi

    # set up rc.conf
    {
        echo "hostname=\"${_containerName}\""
        echo 'sendmail_enable="NONE"'
        echo 'sendmail_submit_enable="NO"'
        echo 'sendmail_outbound_enable="NO"'
        echo 'sendmail_msp_queue_enable="NO"'
        echo 'syslogd_flags="-c -ss"'
        # set up IPFW within the container
        echo 'firewall_enable="YES"'
        echo "firewall_script=\"${CONTAINER_IPFW_SCRIPT}\""
        echo 'firewall_logging="YES"'

    } >> ${_containerMount}/root/etc/rc.conf

    # set up the IPFW script with a shebang
    {
        echo '#!/usr/bin/env sh'
        echo ''
    } > "${_containerMount}/root${CONTAINER_IPFW_SCRIPT}"

    # mount other filesystems for the container
    mount -t devfs devfs "${_containerMount}/root/dev"
    mount -t tmpfs tmpfs "${_containerMount}/root/tmp"

    # set default permissions on /tmp
    chmod 777 "${_containerMount}/root/tmp"

    # set the zfs properties
    zfs_set_property "${_containerDataset}" "${ZFS_PROP_ROOT}:host_hostuuid" "${_uuid}"
    zfs_set_property "${_containerDataset}" "${ZFS_PROP_ROOT}:containername" "${_containerName}"
    zfs_set_property "${_containerDataset}" "${ZFS_PROP_ROOT}:mountpoint" "${_containerMount}"

    # enable the quota on this dataset if it was set
    local _maxHdd=$(zfs_get_property "${_containerDataset}" "${ZFS_PROP_ROOT}:maxhdd")
    if [[ "${_maxHdd}" != "-" ]]; then
        zfs_set_property "${_containerDataset}" "quota" "${_maxHdd}"
    fi

    echo ${_uuid}
    return ${E_SUCCESS}
}

# destroys a zfs container
function zfs_destroy_container() {
    local _partitionName="${1}"
    local _uuid="${2}"

    # make sure the container has stopped
    jail -r "trd-${_uuid}" 2> /dev/null

    # unmount all mount points used by this container
    if ! zfs_unmount_all "${_partitionName}" "${_uuid}"; then
        e_error "Failed to unmount all directories"
    fi

    local _containerDataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${_uuid}"
    local _containerMountPoint="${TREDLY_PARTITIONS_MOUNT}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${_uuid}"

    if [[ -n "${_containerMountPoint}" ]]; then
        # destroy the dataset
        zfs destroy -rf "${_containerDataset}"

        # unmount devfs
        umount -f -t devfs "${_containerMountPoint}/root/dev" 2> /dev/null

        # remove the dir
        rm -rf "${_containerMountPoint}"
    fi
}

# mounts all nullfs basedirs for container
function zfs_mount_basedirs() {
    local _partitionName="${1}"
    local _uuid="${2}"
    local _releaseName="${3}"
    local _dir
    local _mountpoint

    # validate some input
    if [[ ${#_uuid} -eq 0 ]]; then
        return ${E_ERROR}
    fi
    if [[ ${#_releaseName} -eq 0 ]]; then
        return ${E_ERROR}
    fi

    # loop over basedirs and mount them
    for _dir in "${BASEDIRS[@]}"; do
        _mountpoint="${TREDLY_PARTITIONS_MOUNT}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${_uuid}"
        # make sure it exists
        mkdir -p "${_mountpoint}/root/${_dir}" 2> /dev/null

        # mount it
        mount -t nullfs -o ro "${TREDLY_RELEASES_MOUNT}/${_releaseName}/root/${_dir}" "${_mountpoint}/root/${_dir}"

        # if there was an error then stop mounting
        if [[ $? -ne 0 ]]; then
            return ${E_ERROR}
        fi
    done

    return ${E_SUCCESS}
}

# unmount anything mounted by this container
function zfs_unmount_all() {
    local _partitionName="${1}"
    local _uuid="${2}"
    local _dir

    # validate some input
    if [[ ${#_uuid} -eq 0 ]]; then
        return ${E_ERROR}
    fi

    local _containerDataset="${ZFS_TREDLY_PARTITIONS_DATASET}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${_uuid}"
    local _containerMountPoint="${TREDLY_PARTITIONS_MOUNT}/${_partitionName}/${TREDLY_CONTAINER_DIR_NAME}/${_uuid}"

    # get a list of all mounted directories other than devfs

    local _mountedDirs=$( mount | grep ${_containerMountPoint} | grep -Ev "^devfs" | cut -d ' ' -f 3 )

    local _returnCode=0

    IFS=$'\n'
    # loop over basedirs and mount them
    for _dir in ${_mountedDirs}; do
        umount -f "${_dir}"

        _returnCode=$(( ${_returnCode} & $? ))
    done

    return ${_returnCode}
}
