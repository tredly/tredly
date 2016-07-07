#!/usr/bin/env bash

# sets up the environment for tredly
function init_environment() {
    # can be a local path or URL
    local _filesLocation="${1}"

    e_header "Setting up the Tredly environment..."

    # initialise zfs
    e_note "Initialising ZFS datasets"
    zfs_init

    # check if there are runnign containers. if so then exit
    local _containerCount=$( zfs_get_all_containers | wc -l )

    if [[ ${_containerCount} -gt 0 ]]; then
        exit_with_error "This host currently has built containers. Please destroy them and run this command again."
    fi

    # work out which release to pull
    if [[ ${#RELEASES_SUPPORTED[@]} -gt 1 ]]; then
        echo "The following base containers are supported:"
        local _i
        for _i in ${!RELEASES_SUPPORTED[@]}; do
            echo "${_i}. ${RELEASES_SUPPORTED[${_i}]}"
        done

        local _releaseIndex
        while [[ -z "${_releaseIndex}" ]]; do
            read -p "Which would you like to use? " _releaseIndex

            # ensure that the value we received lies within the bounds of the array
            if [[ ${_releaseIndex} -lt 0 ]] || [[ ${_releaseIndex} -ge ${#RELEASES_SUPPORTED[@]} ]] || ! is_int ${_releaseIndex}; then
                echo "Invalid selection. Please try again."
                _releaseIndex=''
            fi
        done

        # set the release name
        _release="${RELEASES_SUPPORTED[${_releaseIndex}]}"
    else
        # we only have 1 so use it by default
        _release="${RELEASES_SUPPORTED[0]}"
    fi

    # if files location was set then check if its a directory otehrwise set to FreeBSD URL
    if [[ -d "${_filesLocation}" ]]; then
        # trim the trailing slash
        _filesLocation=$( rtrim "${_filesLocation}" '/' )
    else
        _filesLocation="https://download.freebsd.org/ftp/releases/amd64/${_release}"
    fi

    # set up the zfs directories/datasets
    zfs_create_dataset "${ZFS_TREDLY_DOWNLOADS_DATASET}/${_release}" "${TREDLY_DOWNLOADS_MOUNT}/${_release}"
    zfs_create_dataset "${ZFS_TREDLY_RELEASES_DATASET}/${_release}" "${TREDLY_RELEASES_MOUNT}/${_release}"
    mkdir -p "${TREDLY_RELEASES_MOUNT}/${_release}/root"

    e_note "Fetching ${_release}"
    cd ${TREDLY_DOWNLOADS_MOUNT}/${_release}

    local -a _filesToDownload
    _filesToDownload+=('base.txz')
    #_filesToDownload+=('doc.txz')
    _filesToDownload+=('lib32.txz')
    _filesToDownload+=('src.txz')

    # fetch the manifest first so we can validate the files as we go along
    fetch ${_filesLocation}/MANIFEST

    local _file
    # fetch the files
    for _file in ${_filesToDownload[@]}; do
        local _download="true"
        local _confirm
        if [[ -e "${_file}" ]]; then
            read -p "${_file} for ${_release} already exists. Do you want to download it again? (y/n) " _confirm
            # if the user hit anything other than y/Y then download the file
            if [ "${_confirm}" != "y" ] && [ "${_confirm}" != "Y" ]; then
                _download="false"
            fi
        fi

        if [[ "${_download}" == "true" ]]; then
            fetch ${_filesLocation}/${_file}
            if [ $? -ne 0 ]; then
                exit_with_error "Failed to download file"
            fi
        fi
    done

    e_note "Validating files in ${_release}"
    # validate the files
    for _file in ${_filesToDownload[@]}; do
        # validate the file
        local _upstreamHash=$( cat MANIFEST | grep ^${_file} | awk -F" " '{ print $2 }' )
        local _localHash=$( sha256 -q ${_file} )

        if [[ "${_upstreamHash}" != "${_localHash}" ]]; then
            exit_with_error "Validation failed on ${_file}. Please try downloading again."
        else
            e_success "Validation passed for ${_file}"
        fi
    done

    # if the release dir already exists then delete everything within it
    if [[ $( ls -1 "${TREDLY_RELEASES_MOUNT}/${_release}/root" 2> /dev/null | wc -l ) -gt 0 ]]; then
        local _confirm
        # confirm with the user that they want to destroy the release
        e_note "Release ${_release} already exists on this system."
        read -p "Do you want to recreate it? (y/n) " _confirm

        if [ "${_confirm}" != "y" ] && [ "${_confirm}" != "Y" ]; then
            exit ${E_ERROR}
        fi

        e_note "Cleaning release ${_release}"

        zfs destroy -rf "${ZFS_TREDLY_RELEASES_DATASET}/${_release}"

        zfs_create_dataset "${ZFS_TREDLY_RELEASES_DATASET}/${_release}" "${TREDLY_RELEASES_MOUNT}/${_release}"
        mkdir -p "${TREDLY_RELEASES_MOUNT}/${_release}/root"

    fi

    e_note "Extracting ${_release}"
    for _file in ${_filesToDownload[@]}; do
        # unzip it
        tar -C ${TREDLY_RELEASES_MOUNT}/${_release}/root -xf ${_file}
    done

    mkdir ${TREDLY_RELEASES_MOUNT}/${_release}/root/usr/home > /dev/null 2>&1
    cd ${TREDLY_RELEASES_MOUNT}/${_release}/root && ln -s usr/home home 2>&1

    mkdir ${TREDLY_RELEASES_MOUNT}/${_release}/root/compat > /dev/null 2>&1
    mkdir ${TREDLY_RELEASES_MOUNT}/${_release}/root/usr/ports > /dev/null 2>&1

    e_note "Updating ${_release}"
    # mount devfs for chroot
    mount -t devfs devfs ${TREDLY_RELEASES_MOUNT}/${_release}/root/dev
    mkdir -p /${TREDLY_RELEASES_MOUNT}/${_release}/root/etc
    cp /etc/resolv.conf /${TREDLY_RELEASES_MOUNT}/${_release}/root/etc/resolv.conf

    # update this release, try 5 times since it likes to fail
    chroot ${TREDLY_RELEASES_MOUNT}/${_release}/root env UNAME_r="${_release}" env PAGER="/bin/cat" freebsd-update --not-running-from-cron fetch

    # install the updates
    chroot ${TREDLY_RELEASES_MOUNT}/${_release}/root env UNAME_r="${_release}" env PAGER="/bin/cat" freebsd-update install
    # verify it
    freebsd-update -b ${TREDLY_RELEASES_MOUNT}/${_release}/root IDS
    if [[ $? -ne 0 ]]; then
        e_error "Failed to verify updates for ${_release}"
    fi

    # unmount dev directory
    umount ${TREDLY_RELEASES_MOUNT}/${_release}/root/dev

    # get the default release
    local _defaultRelease=$( zfs_get_property "${ZFS_TREDLY_DATASET}" "${ZFS_PROP_ROOT}:default_release_name" )
    # if its unset, then set this as the default
    if [[ "${_defaultRelease}" == '-' ]] || [[ -z "${_defaultRelease}" ]]; then
        set_default_release "${_release}"
    else
        e_note "If you wish to use this release by default, then please run \"tredly modify defaultRelease\""
    fi

    e_success "Download and setup of ${_release} complete"
}

# sets the default release to be used when building new containers
function set_default_release() {
    local _releaseName="${1}"

    return $( zfs_set_property "${ZFS_TREDLY_DATASET}" "${ZFS_PROP_ROOT}:default_release_name" "${_releaseName}" )
}

# Allows the user to select their default release
function init_select_default_release() {
    echo "The following base containers are available:"
    local _i

    IFS=$'\n' local _available_releases=($( zfs list -r -H -o name ${ZFS_TREDLY_RELEASES_DATASET} | grep -v 'releases$' | cut -d'/' -f 4 ))
    for _i in ${!_available_releases[@]}; do
        echo "${_i}. ${_available_releases[${_i}]}"
    done

    local _releaseIndex
    while [[ -z "${_releaseIndex}" ]]; do
        read -p "Which would you like to set as default? " _releaseIndex

        # ensure that the value we received lies within the bounds of the array
        if [[ ${_releaseIndex} -lt 0 ]] || [[ ${_releaseIndex} -ge ${#_available_releases[@]} ]] || ! is_int ${_releaseIndex}; then
            echo "Invalid selection. Please try again."
            _releaseIndex=''
        fi
    done

    # set the release
    if set_default_release "${_available_releases[${_releaseIndex}]}"; then
        e_success "Default release is now ${_available_releases[${_releaseIndex}]}"
    else
        e_error "Failed to set default release to ${_available_releases[${_releaseIndex}]}"
    fi
}
