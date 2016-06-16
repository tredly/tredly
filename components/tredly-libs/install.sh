#!/usr/local/bin/bash

# Tredly-Libs installer

PREFIX="/usr/local"
MAN=
BINDIR="${PREFIX}/sbin"
INSTALL=/usr/bin/install
MKDIR="mkdir"
RM="rm"
RMDIR="rmdir"
BINMODE="500"
BASHDIR="${PREFIX}/lib/tredly/bash-common"
PYTHONDIR="${PREFIX}/lib/tredly/python-common"

function show_help() {
    echo "Tredly-Libs installer"
    echo ""
    echo "Usage:"
    echo "    `basename "$0"` install: install Tredly-Libs"
    echo "    `basename "$0"` uninstall: uninstall Tredly-Libs"
    echo "    `basename "$0"` install clean: remove all previously installed files and install Tredly-Libs"
}

# cleans/uninstalls tredly
function clean() {
    # remove any installed files
    ${RM} -f "${BASHDIR}/"*
    ${RM} -rf "${PYTHONDIR}/includes/"*
    ${RM} -rf "${PYTHONDIR}/objects/"*
}

# returns the directory that the files have been downloaded to
function get_files_source() {
    local TREDLY_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

    echo "${TREDLY_DIR}"
}

# check that we received args
if [[ ${#@} -eq 0 ]]; then
    show_help
    exit 1
fi

# where the files are located
FILESSOURCE=$( get_files_source )

# loop over the args, looking for clean first
for arg in "$@"; do
    if [[ "${arg}" == "clean" ]]; then
        echo "Cleaning Tredly-Libs install"
        clean
    fi
done


# now do it again, but do the install/uninstall
for arg in "$@"; do
    case "${arg}" in
        install)
            echo "Installing Tredly-Libs..."
            # copy in the bash libs
            ${MKDIR} -p "${BASHDIR}"
            ${INSTALL} -c "${FILESSOURCE}/bash-common/"* "${BASHDIR}"
            # copy in the python libs
            ${MKDIR} -p "${PYTHONDIR}"
            cp -R "${FILESSOURCE}/python-common/"* "${PYTHONDIR}"

            echo "Tredly-Libs installed."
            ;;
        uninstall)
            echo "Uninstalling Tredly-Libs..."
            # run clean to remove the files
            clean
            echo "Tredly-Libs Uninstalled."
            ;;
        clean)
            # do nothing, this is just here to prevent clean being handled as *
            ;;
        *)
            show_help
            ;;
    esac
done
