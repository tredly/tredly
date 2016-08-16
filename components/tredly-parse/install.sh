#!/usr/local/bin/bash

PREFIX="/usr/local"
MAN=
BINDIR="${PREFIX}/sbin"
LIBDIR="${PREFIX}/lib/tredly-parse"
CONFDIR="${PREFIX}/etc/tredly"
ACTIONSDIR="${LIBDIR}/actions"
INSTALL="/usr/bin/install"
MKDIR="mkdir"
RM="rm"
BINMODE="500"

SCRIPTS="tredly-parse"
SCRIPTSDIR="${PREFIX}/BINDIR"

function show_help() {
    echo "Tredly-Parse installer"
    echo ""
    echo "Usage:"
    echo "    `basename "$0"` install: install Tredly-Parse"
    echo "    `basename "$0"` uninstall: uninstall Tredly-Parse"
    echo "    `basename "$0"` install clean: remove all previously installed files and install Tredly-Parse"
}

# cleans/uninstalls tredly
function clean() {
    # remove any installed files
    ${RM} -f "${BINDIR}/${SCRIPTS}"
    ${RM} -rf "${ACTIONSDIR}/"*
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
        echo "Cleaning Tredly-Parse install"
        clean
    fi
done

# now do it again, but do the install/uninstall
for arg in "$@"; do
    case "${arg}" in
        install)
            echo "Installing Tredly-Parse..."

            ${MKDIR} -p "${BINDIR}"
            ${MKDIR} -p "${LIBDIR}"
            ${MKDIR} -p "${ACTIONSDIR}"
            ${INSTALL} -c -m ${BINMODE} "${FILESSOURCE}/${SCRIPTS}" "${BINDIR}/"

            cp -R "${FILESSOURCE}/actions/" "${ACTIONSDIR}"

            echo "Tredly-Parse installed."
            ;;
        uninstall)
            echo "Uninstalling Tredly-Parse..."
            # run clean to remove the files
            clean
            echo "Tredly-Parse Uninstalled."
            ;;
        clean)
            # do nothing, this is just here to prevent clean being handled as *
            ;;
        *)
            show_help
            ;;
    esac
done
