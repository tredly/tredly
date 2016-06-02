#!/usr/bin/env bash

# a function to perform startup workarounds for postgresql in a container
function workaround_postgresql-server_start() {
    local newUID="${1}"
    local jid="${2}"

    e_note "This container uses postgresql, changing the pgsql UID within this container"
    e_verbose "New UID: ${newUID}"

    # check that this uid isn't already in use on the host
    while [[ $(ps -o uid -ax | grep "^${newUID}$" | wc -l) -ne 0 ]]
    do
        e_verbose "UID ${newUID} already in use."
        # increment the uid by 1 and try again
        newUID=$(($newUID + 1))

        e_verbose "Attempting UID ${newUID}"
    done

    # modify the uid within the container
    eval "jexec ${jid} sh -c '/usr/sbin/pw usermod pgsql -u ${newUID}'"

    e_note "Changing UID of files owned by pgsql"
    # change the ownership of all files with owner uid 70
    eval "jexec ${jid} sh -c 'find / -user 70 -exec chown -h pgsql {} \;'"

}

# a function to perform shutdown workarounds for postgresql in a container
function workaround_postgresql-server_stop() {
    local jid="${1}"

    e_note "Shutting down and cleaning up postgresql"

    # stop postgres server
    eval "jexec ${jid} sh -c '/usr/sbin/service postgresql stop'"

    # get the pgsql uid
    #local _pgsqlUID=$( jexec ${jid} sh -c 'id -u pgsql' )

    #if is_int "${_pgsqlUID}"; then
        #e_verbose "Cleaning up semaphores and shared memory used by postgresql"

        # clean up shared memory and semaphores here in case postgres didnt release the resources
        #local IPCS_S=$( ipcs -s | grep ${_pgsqlUID} | awk '{print $2}' )
        #local IPCS_M=$( ipcs -m | grep ${_pgsqlUID} | awk '{print $2}' )
        #local IPCS_Q=$( ipcs -q | grep ${_pgsqlUID} | awk '{print $2}' )

        #for id in ${IPCS_M}; do
            #ipcrm -m $id
        #done

        #for id in ${IPCS_S}; do
            #ipcrm -s $id
        #done

        #for id in ${IPCS_Q}; do
            #ipcrm -q $id
        #done

    #fi

    return $?
}
