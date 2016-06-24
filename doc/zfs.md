# ZFS
ZFS property arrays are not a native iplementation, but are implemented within Tredly, and are in the form "com.tredly.<arrayname>:<item number>". For example:
* com.tredly.tcpinports:0
* com.tredly.tcpinports:1
* com.tredly.tcpinports:2
* etc

Using this methodology, it is possible to also support associative arrays, however this has not yet been implemented.

## Host Properties
* com.tredly:default_release_name - The name of the release to use by default when building new containers

## Host Property Arrays
None

## Container Properties
* com.tredly:releasename - the release (distro/version) that this container uses
* com.tredly:domainname - Domain part of fqdn
* com.tredly:buildepoch - Time from epoch that container was built
* com.tredly:containername - The name of the container
* com.tredly:containerversion - The container version
* com.tredly:containergroupname - The container group name
* com.tredly:containergroupversion - The container group version
* com.tredly:persistentstorageid - UUID of persistent storage ZFS dataset
* com.tredly:persistentmountpoint - Where persistent storage is mounted
* com.tredly:persistentdataset - The dataset of the mounted persistent storage
* com.tredly:anchorname - Anchor name within PF with this container's firewall rules
* com.tredly:ip6 - the IP6 data 
* com.tredly:maxcpu - maximum cpu available to this container
* com.tredly:maxram - maximum ram available to this container
* com.tredly:allow_quotas - allows disk quotas
* com.tredly:maxhdd - maximum disk space available to container
* com.tredly:endepoch - Time since epoch that container finished building
* com.tredly:mountpoint - Where this container is mounted on the filesystem
* com.tredly:onstopscript - The location within the container of the script to run on stop
* com.tredly:nginx_upstream_dir - The directory on the host where nginx upstream files are kept
* com.tredly:nginx_servername_dir - The directory on the host where nginx servername files are kept
* com.tredly:nginx_accessfile_dir - The directory on the host where nginx access files are kept
* com.tredly:host_iface - The name of the epair A interface on the host
* com.tredly:container_iface - The name of the epair B interface within the container
* com.tredly:securelevel - The securelevel that the container is running in
* com.tredly:hostuuid - UUID of container
* com.tredly:devfs_ruleset - devfs ruleset to apply to container
* com.tredly:enforce_statfs - Determines what information processes in a jail are able to retrieve about mount points.
* com.tredly:children_max - The maximum amount of child containers that this container can have
* com.tredly:allow_set_hostname - Allows a user within the container to set the hostname
* com.tredly:allow_sysvipc - Allow SysV IPC (inter-process communication) within the container. Necessary for PostgreSQL.
* com.tredly:allow_raw_sockets - Allows the container to create raw sockets. Useful for ping, traceroute etc.
* com.tredly:allow_chflags - Allows a container to change immutable flags.
* com.tredly:allow_mount - Allows a container to mount filesystems.
* com.tredly:allow_mount_devfs - Allows a container to mount devfs filesystems.
* com.tredly:allow_mount_procfs - Allows a container to mount procfs filesystems.
* com.tredly:allow_mount_tmpfs - Allows a container to mount tmpfs filesystems.
* com.tredly:allow_mount_zfs - Allows a container to mount ZFS filesystems.
* com.tredly:allow_mount_nullfs - Allows a container to mount nullfs filesystems.
* com.tredly:allow_quotas - Allows quotas to be applied on container filesystems.
* com.tredly:allow_socket_af - Allows access to non standard (IP4, IP6, unix and route) protocol stacks within the container.
* com.tredly:exec_prestart - Script to run before starting container.
* com.tredly:exec_poststart - Script to run after starting container.
* com.tredly:exec_prestop - Script to run before stopping container.
* com.tredly:exec_stop -  Script to run when stopping container
* com.tredly:exec_clean - Run commands in a clean environment
* com.tredly:exec_timeout - Timeout to wait for a command to complete.
* com.tredly:exec_fib - The FIB to use when running commands within a container.
* com.tredly:stop_timeout - Timeout to wait for a container to stop.
* com.tredly:containerstate - Container state - allows us to display soemthing descriptive to the user when for example the container is being replaced
* com.tredly:partition - the name of the partition this container resides in

## Container Property Arrays
* com.tredly.tcpinports - array of tcpinports from tredlyfile
* com.tredly.tcpoutports - array of tcpoutports from tredlyfile
* com.tredly.udpinports - array of udpinports from tredlyfile
* com.tredly.udpoutports - array of udpoutports from tredlyfile
* com.tredly.jsonurls - jsonified URL objects
* com.tredly.url - array of translated urls from tredlyfile
* com.tredly.url_cert - array of translated urlCerts from tredlyfile 
* com.tredly.redirect_url - array of redirected urls set up for this container
* com.tredly.redirect_url_cert - array of certificates for redirected (https) urls set up for this container
* com.tredly.dns - array of dns servers this container uses
* com.tredly.nginx_servername - a list of filenames (not full paths) of nginx server_name files associated with this container. Used for cleanup on destroy.
* com.tredly.nginx_upstream - a list of filenames (not full paths) of nginx upstream files associated with this container. Used for cleanup on destroy.
* com.tredly.registered_dns_names - array of hostnames associated with this container
* com.tredly.layer4proxytcp - array of tcp ports set up for layer 4 proxy
* com.tredly.layer4proxyudp - array of udp ports set up for layer 4 proxy

## Partition Properties
* quota - max disk usage
* com.tredly:partitionname - name of partition
* com.tredly:maxcpu - max amount of cpu for this partition
* com.tredly:maxram - max amount of ram for this partition
* com.tredly:nginx_whitelist_accessfile - the path to the nginx whitelist access file for this partition

## Partition Property Arrays
* com.tredly.publicips - array of public ips assigned to partition
* com.tredly.ptn_ip4whitelist - array of ips to whitelist