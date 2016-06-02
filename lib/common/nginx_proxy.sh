#!/usr/bin/env bash

# Reloads Nginx
function nginx_reload() {
    service nginx reload > /dev/null 2>&1

    return $?
}

# Creates a server file for nginx
function nginx_create_servername_file() {

    local _subdomain="${1}"
    local _filePath="${2}"
    local _certificate="${3}"
    local _errorDocs="${4}"

    # output the config to the file
    {
        echo "server {"
        echo "    server_name ${_subdomain};"
        # if a certificate was received then include https
        if [[ -n "${_certificate}" ]]; then
            # HTTPS
            echo "    listen ${_CONF_COMMON[httpproxy]}:443 ssl;"
            # enable ssl and include the cert/key
            echo "    ssl on;"
            echo "    ssl_certificate ssl/${_certificate}/server.crt;"
            echo "    ssl_certificate_key ssl/${_certificate}/server.key;"
        else
            # HTTP
            echo "    listen ${_CONF_COMMON[httpproxy]}:80;"
        fi
        
        if [[ "${_errorDocs}" == "true" ]]; then
            # insert the location block for error files if it was requested
            echo "    location /tredly_error_docs {"
            echo "        alias /usr/local/etc/nginx/tredly_error_docs;"
            echo "        log_not_found off;"
            echo "        access_log off;"
            echo "    }"
            echo "    error_page 404 /tredly_error_docs/404.html;"
        fi
        
        echo "}"
    } > "${_filePath}"

    return $?
}

# Creates an upstream file for nginx
function nginx_create_upstream_file() {
    local _upstreamName="${1}"
    local _filePath="${2}"
    {
        echo "upstream ${_upstreamName} {"
        echo "}"
    } > "${_filePath}"
    return $?
}

# Adds an ip4 and port to an upstream block within an upstream file
function nginx_add_to_upstream_block() {
    local _file="${1}"
    local _ip4="${2}"
    local _port="${3}"
    local _upstreamName="${4}"

    # include the server line in the upstream file
    local _lineToAdd="server ${_ip4}:${_port};"

    # check if the server line exists
    local _lineExists=$(cat "${_file}" | grep "${_lineToAdd}" | wc -l )

    if [[ ${_lineExists} -eq 0 ]]; then
        # add in the ip address and port
        add_line_to_file_after_string "    ${_lineToAdd}" "upstream ${_upstreamName} {" "${_file}"
    fi
}

# adds the location data to the upstream file if it doesnt already exist
function nginx_add_location_block() {
    local _urlPath="${1}"
    local _filePath="${2}"
    local _ssl="${3}"

    local _listenLine="listen ${_CONF_COMMON[httpproxy]}"

    local locationExists

    # check if this definition already exists in the nginx config
    if [[ $(cat "${_filePath}" | grep "location ${_urlPath} {" | wc -l ) -eq 0 ]]; then

        # check if its an ssl location or not
        if [[ "${_ssl}" == "true" ]]; then
            _listenLine="${_listenLine}:443 ssl;"
        else
            _listenLine="${_listenLine}:80;"
        fi

        e_verbose "Adding location data to ${_filePath}"

        # add a fresh definition
        $(add_line_to_file_after_string "    location ${_urlPath} {" "${_listenLine}" "${_filePath}")
        # add the closing brace
        $(add_line_to_file_after_string "    }" "    location ${_urlPath} {" "${_filePath}")

        return ${E_SUCCESS}
    else
        e_verbose "Location data already in ${_filePath}"
        return ${E_ERROR}
    fi

}

# Inserts location data to a servername file
function nginx_insert_location_data() {
    local _upstreamFilename="${1}"
    local _urlDirectory="${2}"
    local _filePath="${3}"
    local _urlWebSocket="${4}"
    local _urlMaxFileSize="${5}"
    local _ssl="${6}"
    local _protocol="http"

    if [[ "${_ssl}" == "true" ]]; then
        _protocol="https"
    fi

    # get a copy of the location block
    local _locationBlock=$( get_data_between_strings "location ${_urlDirectory} {" "}" "$( cat "${_filePath}" )" )

    # now add in the proxy pass/bind
    # bind is necessary for the proxy request to come from the correct IP address
    add_line_to_file_between_strings_if_not_exists "location ${_urlDirectory} {" "        proxy_pass ${_protocol}://${_upstreamFilename};" "}" "${_filePath}"
    add_line_to_file_between_strings_if_not_exists "location ${_urlDirectory} {" "        proxy_bind ${_CONF_COMMON[httpproxy]};" "}" "${_filePath}"

    # check if this url is a websocket url and add in the relevant config
    if [[ "${_urlWebSocket}" == "yes" ]]; then
        # include the websockets proxy file
        add_line_to_file_between_strings_if_not_exists "location ${_urlDirectory} {" "        include proxy_pass/ws_wss;" "}" "${_filePath}"
    else
        # include the standard HTTP(S) proxy file
        add_line_to_file_between_strings_if_not_exists "location ${_urlDirectory} {" "        include proxy_pass/http_https;" "}" "${_filePath}"
    fi

    # check if this url has a max file size setting
    if [[ -n "${_urlMaxFileSize}" ]]; then
        add_line_to_file_between_strings_if_not_exists "location ${_urlDirectory} {" "        client_max_body_size ${_urlMaxFileSize};" "}" "${_filePath}"
    fi
}

# creates an access file for a given location - includes allow and deny rules
function nginx_create_access_file() {
    local _accessFile="${1}"
    local -a _ip4wl=("${!2}")
    local _addDenyRule="${3}"

    local ip4wl
    local _accessDir=$( dirname "${_accessFile}" )

    # make sure the directory exists
    if [[ ! -d "${_accessDir}" ]]; then
        mkdir -p "${_accessDir}"
    fi

    # create the file
    touch "${_accessFile}"
    chmod 600 "${_accessFile}"

    # populate it
    {
        # make sure we have more than 0 ips to whitelist before adding the rules
        if [[ ${#_ip4wl[@]} -gt 0 ]]; then
            # loop over the whitelisted ips and allow them after validating
            for ip4wl in ${_ip4wl[@]}; do
                # validate it
                if is_valid_ip4 "${ip4wl}"; then
                    echo "allow ${ip4wl};"
                fi
            done

        else # default - allow all
            echo "allow all;"
        fi

        # add in a deny all if hte user wanted it
        if [[ "${_addDenyRule}" == "true" ]]; then
            echo "deny all;"
        fi
    } > "${_accessFile}"

    return ${E_SUCCESS}
}

# clears out an access file
function nginx_clear_access_file() {
    local _accessFile="${1}"

    if [[ -f "${_accessFile}" ]]; then
        echo '' > "${_accessFile}"

        return $?
    fi


    return ${E_ERROR}
}

# formats a given filename into the correct format for nginx
function nginx_format_filename() {
    local filename="${1}"
    # swap :// for dash
    filename=$(echo "${filename}" | sed "s|://|-|" )
    # swap dots for underscores
    filename=$(echo "${filename}" | tr '.' '_')
    # and slashes for dashes
    filename=$(echo "${filename}" | tr '/' '-')

    echo "${filename}"
    return ${E_SUCCESS}

}

# removes an include line from nginx
function nginx_remove_include() {
    local _include=$( regex_escape "${1}" )
    local _file="${2}"

    # remove the lines from the file
    if remove_lines_from_file "${_file}" "include ${_include};" "false"; then
        return ${E_SUCCESS}
    fi

    return ${E_ERROR}
}

# sets up a url with given parameters
function nginx_add_url() {
    local _url="${1}"
    local _urlCert="${2}"
    local _urlWebSocket="${3}"
    local _urlMaxFileSize="${4}"
    local _ip4="${5}"
    local _uuid="${6}"
    local _container_dataset="${7}"
    declare -a _whiteList=("${!8}")

    local _urlDomain _urlDirectory _filename _upstreamFilename

    # split up the url into its domain and directory segments
    # check if the url actually contained a /
    if string_contains_char "${_url}" '/'; then
        _urlDomain=$(lcut ${_url} '/')
        _urlDirectory=$(rcut ${_url} '/')
        # add the / back in
        _urlDirectory="/${_urlDirectory}"
    else
        _urlDomain="${_url}"
        _urlDirectory='/'
    fi

    # remove any trailing slashes
    #local _filename=$(rtrim "${_url}" '/')
    local _filename=$(rtrim "${_urlDomain}" '/')
    local _upstreamFilename=$( rtrim "${_url}" '/' )

    # format the filename of the file to edit - swap dots for underscores
    _filename=$( nginx_format_filename "${_filename}" )
    _upstreamFilename=$( nginx_format_filename "${_upstreamFilename}" )

    # check if this is a ssl url
    if [[ -n "${_urlCert}" ]]; then
        #####################################
        # SET UP THE HTTPS UPSTREAM FILE
        # check if the https upstream file exists
        if [[ ! -f "${NGINX_UPSTREAM_DIR}/https-${_upstreamFilename}" ]]; then
            # create it
            if ! nginx_create_upstream_file "https-${_upstreamFilename}" "${NGINX_UPSTREAM_DIR}/https-${_upstreamFilename}"; then
                e_error "Failed to create HTTP proxy upstream file ${NGINX_UPSTREAM_DIR}/https-${_upstreamFilename}"
            fi
        fi

        # add the ip address to the https upstream block
        nginx_add_to_upstream_block "${NGINX_UPSTREAM_DIR}/https-${_upstreamFilename}" "${_ip4}" "443" "https-${_upstreamFilename}"

        # include this file in the dataset for destruction
        zfs_append_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.nginx_upstream" "https-${_upstreamFilename}"

        #####################################
        # SET UP THE HTTPS SERVER_NAME FILE
        # check if the https server_name file exists
        if [[ ! -f "${NGINX_SERVERNAME_DIR}/https-${_filename}" ]]; then
            # create it
            if ! nginx_create_servername_file "${_urlDomain}" "${NGINX_SERVERNAME_DIR}/https-${_filename}" "${_urlCert}" "true"; then
                e_error "Failed to create HTTPS proxy servername file ${NGINX_SERVERNAME_DIR}/https-${_filename}"
            fi
        fi

        # add the location data if it doesnt already exist
        nginx_add_location_block "${_urlDirectory}" "${NGINX_SERVERNAME_DIR}/https-${_filename}" "true"
        # insert the additional location data
        nginx_insert_location_data "https-${_upstreamFilename}" "${_urlDirectory}" "${NGINX_SERVERNAME_DIR}/https-${_filename}" "${_urlWebsocket}" "${_urlMaxFileSize}" "true"
        # include this file in the dataset for destruction
        zfs_append_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.nginx_servername" "https-${_filename}"

        #####################################
        # SET UP THE HTTP REDIRECT SERVER_NAME FILE
        nginx_add_redirect_url "http://${_url}" "https://${_url}"

        # register the redirect url within zfs
        zfs_append_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.redirect_url" "http://${_url}"

        # Include the access file for this container in the server_name file
        local _accessFileName=$( nginx_format_filename "${_uuid}" )

        local _accessFilePath="${NGINX_ACCESSFILE_DIR}/${_accessFileName}"

        # now create the access file if we received whitelist data
        if [[ ${#_whiteList[@]} -gt 0 ]]; then
            nginx_create_access_file "${_accessFilePath}" _whiteList[@] "true"
            # add a deny all into the server file so that we can reference many allows from includes
            #$(add_line_to_file_after_string "        deny all;" "location ${_urlDirectory} {" "${NGINX_SERVERNAME_DIR}/https-${_filename}")

            # and include the access file for this container
            $(add_line_to_file_after_string "        include ${_accessFilePath};" "location ${_urlDirectory} {" "${NGINX_SERVERNAME_DIR}/https-${_filename}");
        fi
    else
        #####################################
        # SET UP THE HTTP UPSTREAM FILE
        # check if the https upstream file exists
        if [[ ! -f "${NGINX_UPSTREAM_DIR}/http-${_upstreamFilename}" ]]; then
            # create it
            if ! nginx_create_upstream_file "http-${_upstreamFilename}" "${NGINX_UPSTREAM_DIR}/http-${_upstreamFilename}"; then
                e_error "Failed to create HTTP proxy upstream file ${NGINX_UPSTREAM_DIR}/http-${_upstreamFilename}"
            fi
        fi

        # add the ip address to the https upstream block
        nginx_add_to_upstream_block "${NGINX_UPSTREAM_DIR}/http-${_upstreamFilename}" "${_ip4}" "80" "http-${_upstreamFilename}"
        # include this file in the dataset for destruction
        zfs_append_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.nginx_upstream" "http-${_upstreamFilename}"
        #####################################
        # SET UP THE HTTP SERVER_NAME FILE

        # check if the https server_name file exists
        if [[ ! -f "${NGINX_SERVERNAME_DIR}/http-${_filename}" ]]; then
            # create it
            if ! nginx_create_servername_file "${_urlDomain}" "${NGINX_SERVERNAME_DIR}/http-${_filename}" "${_urlCert}" "true"; then
                e_error "Failed to create HTTP proxy servername file ${NGINX_SERVERNAME_DIR}/http-${_filename}"
            fi
        fi

        # add the location data if it doesnt already exist
        nginx_add_location_block "${_urlDirectory}" "${NGINX_SERVERNAME_DIR}/http-${_filename}" "false"
        # insert the additional location data
        nginx_insert_location_data "http-${_upstreamFilename}" "${_urlDirectory}" "${NGINX_SERVERNAME_DIR}/http-${_filename}" "${_urlWebsocket}" "${_urlMaxFileSize}" "false"
        # include this file in the dataset for destruction
        zfs_append_custom_array "${_container_dataset}" "${ZFS_PROP_ROOT}.nginx_servername" "http-${_filename}"

        # Include the access file for this container in the server_name file
        local _accessFileName=$( nginx_format_filename "${_uuid}" )
        local _accessFilePath="${NGINX_ACCESSFILE_DIR}/${_accessFileName}"

        # now create the access file if we received whitelist data
        if [[ ${#_whiteList[@]} -gt 0 ]]; then
            nginx_create_access_file "${_accessFilePath}" _whiteList[@]
            # add a deny all into the server file so that we can reference many allows from includes
            $(add_line_to_file_after_string "        deny all;" "location ${_urlDirectory} {" "${NGINX_SERVERNAME_DIR}/http-${_filename}")

            # and include the access file for this container
            $(add_line_to_file_after_string "        include ${_accessFilePath};" "location ${_urlDirectory} {" "${NGINX_SERVERNAME_DIR}/http-${_filename}");
        fi
    fi
}

# adds a url definition that is redirected to another url
# takes a single from and a single to
function nginx_add_redirect_url() {
    local _redirectFrom="${1}"
    local _redirectTo="${2}"
    local _redirectFromCert="${3}"
    local _partitionName="${4}"

    local _urlFromCert _urlFromDomain _urlFromDirectory _transformedRedirectFrom

    # check if it starts with a protocol
    if [[ "${_redirectFrom}" =~ ^https ]]; then
        # HTTPS url
        _urlFromSSL="true"
        # strip off the https part
        _transformedRedirectFrom=${_redirectFrom#https://}

    elif [[ "${_redirectFrom}" =~ ^http ]]; then
        _urlFromSSL="false"
        # strip off the http part
        _transformedRedirectFrom=${_redirectFrom#http://}
    else
        # no protocol received so error
        return ${E_ERROR}
    fi

    # check if the url actually contained a /
    if string_contains_char "${_transformedRedirectFrom}" '/'; then
        _urlFromDomain=$(lcut ${_transformedRedirectFrom} '/')
        _urlFromDirectory=$(rcut ${_transformedRedirectFrom} '/')
        # add the / back in
        _urlFromDirectory="/${_urlFromDirectory}"
    else
        _urlFromDomain="${_transformedRedirectFrom}"
        _urlFromDirectory='/'
    fi

    # remove any trailing slashes
    local _servernameFilename=$(rtrim "${_urlFromDomain}" '/')
    local _upstreamFilename=$( rtrim "${_transformedRedirectFrom}" '/' )

    # format the filename of the file to edit - swap dots for underscores
    _servernameFilename=$( nginx_format_filename "${_servernameFilename}" )
    _upstreamFilename=$( nginx_format_filename "${_upstreamFilename}" )

    # prepend the protocol to the start of servername filename
    if [[ "${_redirectFrom}" =~ ^https ]]; then
        _servernameFilename="https-${_servernameFilename}"
        _urlFromCert="${_redirectFromCert}"
    else
        _servernameFilename="http-${_servernameFilename}"
    fi
    
    # add the partition name to the cert path if we have a certificate
    if [[ -n "${_urlFromCert}" ]]; then
        _urlFromCert="${_partitionName}/${_urlFromCert}"
    fi

    # check if the https server_name file exists
    if [[ ! -f "${NGINX_SERVERNAME_DIR}/${_servernameFilename}" ]]; then
        # create it
        if ! nginx_create_servername_file "${_urlFromDomain}" "${NGINX_SERVERNAME_DIR}/${_servernameFilename}" "${_urlFromCert}" "false"; then
            return ${E_ERROR}
        fi
    fi

    # add the location data if it doesnt already exist
    if ! nginx_add_location_block "${_urlFromDirectory}" "${NGINX_SERVERNAME_DIR}/${_servernameFilename}" "${_urlFromSSL}"; then
        return ${E_ERROR}
    fi

    # insert the redirect
    if ! add_line_to_file_between_strings_if_not_exists "location ${_urlFromDirectory} {" "        return 301 ${_redirectTo}\$request_uri;" "}" "${NGINX_SERVERNAME_DIR}/${_servernameFilename}"; then
        return ${E_ERROR}
    fi

    return ${E_SUCCESS}
}

# copies an nginx cert into a given directory
function nginx_copy_cert() {
    local _cert="${1}"
    local _partitionName="${2}"
    local _src
    local _exitCode=0

    # if first word of the source is "partition" then the file comes from the partition
    if [[ "${_cert}" =~ ^partition/ ]]; then
        local _certPath="$(rcut "${_cert}" "/" )"
        _src="${TREDLY_PARTITIONS_MOUNT}/${_partitionName}/${TREDLY_PTN_DATA_DIR_NAME}/${_certPath}/"
    else
        _src="$(rtrim ${_CONTAINER_CWD} /)/$( ltrim ${_cert} / )/"
    fi

    # trim urlcert down to the last dir name
    local _cert="$(echo "${_cert}" | rev | cut -d '/' -f 1 | rev )"

    # form a full path
    local _certDestDir="${NGINX_SSL_DIR}/${_partitionName}/${_cert}"
    
    # check if directory already exists
    if [[ -d "${_certDestDir}" ]]; then
        # it does - we dont want to overwrite this cert so return
        return ${E_SUCCESS}
    else
        # create the dir
        mkdir -p ${_certDestDir}
        
        # copy the files across
        copy_files "${_src}" "${_certDestDir}"
        _exitCode=$?
        
        # change ownership of ssl cert and key
        chown -R www "${_certDestDir}"
        _exitCode=$(( ${_exitCode} & $? ))

        chgrp -R www "${_certDestDir}"
        _exitCode=$(( ${_exitCode} & $? ))

        # only allow www to read the private key
        chmod 600 "${_certDestDir}/server.key"
        _exitCode=$(( ${_exitCode} & $? ))

        return ${_exitCode}
    fi

}
