# IPFW

## Host Firewall

### Reserved Rule Numbers
* 150 - Tredly-API access
* 151 - 159 - Tredly-API reserved for future use

### Tables
* 1 - Contains all public ip4 addresses assigned to containers
* 2 - Contains all epairs assigned to public containers
* 5 - Contains all public ip4 addresses that this host responds on
* 6 - Contains all public interfaces that this host responds on
* 7 - Contains the host's private ip address
* 10 - Contains private container subnet
* 11 - Contains private container interface
* 20 - Contains all IP4 addresses whitelisted for Tredly-API Access
* 50 - Fail2Ban blocked IP addresses

## Container Firewall

### Tables
* 1 - Contains ip4 addresses of group members
* 2 - Contains ip4 addresses of partition whitelist
* 3 - Contains ip4 addresses of container whitelist
