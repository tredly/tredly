#!/usr/local/bin/bash

PREFIX="/usr/local"
MAN=
BINDIR="${PREFIX}/sbin"
LIBDIR="${PREFIX}/lib/tredly-build"
CONFDIR="${PREFIX}/etc/tredly"
ACTIONSDIR="${LIBDIR}/actions"
INSTALL="/usr/bin/install"
MKDIR="mkdir"
RM="rm"
BINMODE="500"

SCRIPTS="tredly-build"
SCRIPTSDIR="${PREFIX}/BINDIR"

function show_help() {
    echo "Tredly-Build installer"
    echo ""
    echo "Usage:"
    echo "    `basename "$0"` install: install Tredly-Build"
    echo "    `basename "$0"` uninstall: uninstall Tredly-Build"
    echo "    `basename "$0"` install clean: remove all previously installed files and install Tredly-Build"
}

# cleans/uninstalls tredly
function clean() {
    # remove any installed files
    ${RM} -f "${BINDIR}/${SCRIPTS}"
    ${RM} -rf "${ACTIONSDIR}/"*

    ${RM} -f "${CONFDIR}/json/tredlyfile.schema.json"
    
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
        echo "Cleaning Tredly-Build install"
        clean
    fi
done

# now do it again, but do the install/uninstall
for arg in "$@"; do
    case "${arg}" in
        install)
            echo "Installing Tredly-Build..."
            
            ${MKDIR} -p "${BINDIR}"
            ${MKDIR} -p "${LIBDIR}"
            ${MKDIR} -p "${CONFDIR}/json"
            ${MKDIR} -p "${ACTIONSDIR}"
            ${INSTALL} -c -m ${BINMODE} "${FILESSOURCE}/${SCRIPTS}" "${BINDIR}/"

            cp -R "${FILESSOURCE}/actions/" "${ACTIONSDIR}"

            cp "${FILESSOURCE}/json/tredlyfile.schema.json" "${CONFDIR}/json/"

            echo "Tredly-Build installed."
            ;;
        uninstall)
            echo "Uninstalling Tredly-Build..."
            # run clean to remove the files
            clean
            echo "Tredly-Build Uninstalled."
            ;;
        clean)
            # do nothing, this is just here to prevent clean being handled as *
            ;;
        *)
            show_help
            ;;
    esac
done
