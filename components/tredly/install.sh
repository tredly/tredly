#!/usr/local/bin/bash

# Tredly-Core installer

PREFIX="/usr/local"
MAN=
BINDIR="${PREFIX}/sbin"
COMMANDSDIR="${PREFIX}/lib/tredly/commands"
INSTALL=/usr/bin/install
MKDIR="mkdir"
RM="rm"
BINMODE="500"

SCRIPTS="tredly"
SCRIPTSDIR="${PREFIX}/BINDIR"

# cleans/uninstalls tredly
function clean() {
    # remove any installed files
    ${RM} -f "${BINDIR}/${SCRIPTS}"
    ${RM} -f "${COMMANDSDIR}/"*
}

# returns the directory that the files have been downloaded to
function get_files_source() {
    local TREDLY_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

    echo "${TREDLY_DIR}"
}

# where the files are located
FILESSOURCE=$( get_files_source )

# loop over the args, looking for clean first
for arg in "$@"; do
    if [[ "${arg}" == "clean" ]]; then
        echo "Cleaning Tredly-Core install"
        clean
    fi
done

# now do it again, but do the install/uninstall
for arg in "$@"; do
    case "${arg}" in
        install)
            echo "Installing Tredly-Core..."
            ${MKDIR} -p "${BINDIR}"
            ${MKDIR} -p "${COMMANDSDIR}"
            ${INSTALL} -c -m ${BINMODE} "${FILESSOURCE}/${SCRIPTS}" "${BINDIR}/"
            ${INSTALL} -c "${FILESSOURCE}/commands/"* "${COMMANDSDIR}"
            echo "Tredly-Core installed."
            ;;
        uninstall)
            echo "Uninstalling Tredly-Core..."
            # run clean to remove the files
            clean
            echo "Tredly-Core Uninstalled."
            ;;
        clean)
            # do nothing, this is just here to prevent clean being handled as *
            ;;
        *)
            echo "Tredly-Core installer"
            echo ""
            echo "Usage:"
            echo "    `basename "$0"` install: install tredly-Core"
            echo "    `basename "$0"` uninstall: uninstall tredly-Core"
            echo "    `basename "$0"` install clean: remove all previously installed files and install tredly-Core"
            ;;
    esac
done
