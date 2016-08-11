# Tredly Commands
```
usage: tredly <action> <subject> <option> [<args>]
```
A Tredly command comprises of 4 main parts. Firstly, the action. The available actions change based on the subject. For instance, api has 2 actions, where as container has several.

The second part is the subject. There are 9 different subjects in Tredly, and each subject has a different set of possible actions:

    api
    container
    host
    console
    partition
    defaultRelease
    commandcenter
    dns
    layer7proxy

Next are the options and args. These are specific to the subject and action being used. Options are akin to 'sub-actions', whereas args are usually input such as a path to a file or ip address.

Document Conventions
Each subject has a dedicated section. Within each section is a breakdown of all actions available to that subject, as well as the options and their arguments.

There are 2 keywords used throughout this document: optional and interactive. They will always appear at the end of documentation relating to an option or argument.

- optional means that particular option or argument is not required.
- interactive means that using running that option will require input from the user that cannot be specified on the command line itself. An example of this is tredly config api password which will prompt the user for a password.


## API
```
tredly <action> api <option>
```
api has two actions, config and status (see "Status" below for more information on the status‚ action).

### Config

    password - Allows changing of the password (interactive)
    whitelist - Whitelist specified IP addresses, allowing traffic from them to interact with the Tredly API (interactive)

### Examples
```
tredly config api password
tredly status api
```

## Initialising Tredly
```
tredly init
```
Does not have any options or arguments.

init will display a list of supported releases and download, set up and patch as necessary the selected release. Note that this is will run automatically during the Tredly installation process.

Note that initialising a release will not mean it is used for container creation. You must change the default release with tredly modify defaultRelease before it will be used for new containers.

Whenever the default release has been changed with tredly modify defaultRelease, you should also run tredly init.

## Modifying Default release
```
tredly modify defaultRelease
```
Changes the FreeBSD release used when creating or replacing containers. A list of supported releases will then be displayed to select from. All containers created or replaced will then be built using the selected release.

When changing the default release, it is recommended to also run tredly init.

## Network Configuration
```
tredly config host <option> [<args>]
tredly config container subnet <value>
```
The host subject has only 1 action: config. It allows changing of the host and container network configuration. There are 4 possible network options for the host (gateway, hostname, network and dns) and 1 option for container (subnet).

    network - Changes the external interface, IP/subnet and gateway. Must provide an external interface, external ip address range and external interface gateway IP address.
    gateway - Changes the external interface gateway. Must provide an IP address.
    hostname - Changes the Tredly hostname value.
    dns - Sets the DNS records for this host. Must provide a comma separated list of IP addresses.
    subnet - Change the subnet from which containers are allocated private IP addresses.

### Examples
```
tredly config container subnet 10.0.0.0/8
tredly config host network em0 192.168.0.20/24 192.168.0.1
tredly config host DNS 1.2.3.4,5.6.7.8
tredly config host gateway 192.168.0.254
tredly config host hostname MyNewTredlyHostName
```

## Status

Displays the current status of the specified subject. Note that status has no additional options.

Possible subjects are commandcenter, api, dns and layer7proxy.

### Example
```
tredly status commandcenter
tredly status api
```

## Partition
The partition subject has 3 possible actions: create, destroy and modify. Each action shares the same set of options.

### Create a Partition
```
tredly create partition <PartitionName> CPU=<value> RAM=<value> HDD=<value> ipv4Whitelist=[<ip>,<ip>,...,<ip>]
```
    partitionName - A unique name for this partition. It can only container letters, numbers, underscores (_) and dashes (-).
    CPU - The total number of CPU cores or percentage of CPU this partition is allocated. Must be a number, or a number and a percentage sign. E.g. CPU=1 and CPU=20%
    RAM - The total amount of RAM, in gigabytes or megabytes, this partition is allocated. Must be a number followed by G or M to denote either gigabytes or megabytes. E.g. RAM=1G or RAM=1024M
    HDD - The total amount of disk space, in gigabytes, this partition is allocated. Must be a number followed by G or M to denote either gigabytes or megabytes. E.g. HDD=1G or HDD=1024M
    ipv4Whitelist - A comma separated list of IPv4 addresses to whitelist. Traffic from these IP addresses will be allowed to reach the partition.

### Modify a Partition
```
tredly modify partition <PartitionName> partitionName=<newPartitionName> CPU=<value> RAM=<value> HDD=<value> ipv4Whitelist=[<ip>,<ip>,...,<ip>]
```
    partitionName - The name of the partition to be modified.
    newPartitionName - The new name this partition will take. It can only container letters, numbers, underscores (_) and dashes (-)
    CPU - The total number of CPU cores or percentage of CPU this partition is allocated. Must be a number, or a number and a percentage sign. E.g. CPU=1 and CPU=20%
    RAM - The total amount of RAM, in gigabytes, this partition is allocated. Must be a number followed by Gor M to denote either gigabytes or megabytes. E.g. RAM=1G or RAM=1024M
    HDD - The total amount of disk space, in gigabytes, this partition is allocated. Must be a number followed by G or M to denote either gigabytes or megabytes. E.g. HDD=1G or HDD=1024M
    ipv4Whitelist - A comma separated list of IPv4 addresses to whitelist. Traffic from these IP addresses will be allowed to reach the partition.

### Destroy a Partition

This will destroy the specified partition, plus all the containers and any persistent storage attached to that partition.
```
tredly destroy partition <PartitionName>
```
    partitionName - The name the partition to destroy. Get a list of Partitions with tredy list partitions

### Examples
```
tredly create partition MyPartition CPU=20% RAM=2G HDD=40G ipv4Whitelist=10.1.1.1,192.168.15.23
tredly modify partition MyPartition partitionName=AnotherName CPU=10% RAM=1G HDD=20G
tredly destroy partition MyPartition
```

## Container
The container subject has the following 9 actions: command, config, destroy, modify, start, stop, validate, replace and create

### Create a container

Creating a container requires a Tredlyfile. If no path is provided, Tredly will look in the current directory for one.
```
tredly create container [<partition>] [--location=<value>]
```
    partition - The name of the partition this container should belong to. If the partition does not exist, Tredly will return an error. (optional)
    --location - Specify the path to the Tredlyfile and any supporting files needed for installation. if not set, Tredly‚ searches the current directory. (optional)

### Replace a container
```
tredly replace container <partition> --location=<value> [<uuid>]
```
    partition - Required. The name of the partition the container belongs to. If the container was not explicitly assigned to a partition, it will reside in‚ the default partition.
    --location - Required. Specify the path to the Tredlyfile and any supporting files needed. Unlike create, this is required.
    uuid - Specify the UUID of the container. If this is not set, Tredly will attempt to deduce the relevant container based on the Tredlyfile located from the --locationÂ argument. (optional)

### Destroy a container

Destroys a container, removing all files and, if it is still running, triggers any onStop operations. This is an interactive command, prompting for confirmation before continuing.
```
tredly destroy container <uuid>
```
    uuid - The UUID of the container to be destroyed.

### Starting & Stopping Containers

This will start or stop a container. When stopping a container, any onStop operations specified in the Tredlyfile will also be run.
```
tredly start container <uuid>
tredly stop container <uuid>
```
    uuid - The UUID of the container to be started/stopped.

### Stopping Multiple Containers

Multiple containers can be stopped using the following command:
```
tredly stop containers <partition name>
```
    partition name - the partition the containers reside in

If partition name is blank, all containers will be stopped. This is particularly useful to stop all containers before rebooting or shutting down a host.

### Modify a container

Allows the reallocation of resources and changing of IP whitelist.
```
tredly modify container <uuid> CPU=<value> RAM=<value> HDD=<value> ipv4Whitelist=[<ip>,<ip>,...,<ip>]
```
    uuid - The UUID of the container to run the command in.
    CPU - The total number of CPU cores or percentage of CPU this partition is allocated. Must be a number, or a number and a percentage sign. E.g. CPU=1 and CPU=20%
    RAM - The total amount of RAM, in gigabytes, this partition is allocated. Must be a number followed by G. E.g. RAM=1G
    HDD - The total amount of disk space, in gigabytes, this partition is allocated. Must be a number followed by G. E.g. HDD=1G
    ipv4Whitelist - A comma seperated list of IPv4 addresses to whitelist. Traffic from these IP addresses will be allowed to reach the partition.

#### Example
```
tredly modify container 25es24fg CPU=20% RAM=2G HDD=40G ipv4Whitelist=10.1.1.1,192.168.15.23
```

### Run command inside container

It is possible to run any command inside of a container without having to use tredly console. This action will run the specified command inside the container with the provided UUID.
```
tredly command container <uuid> <command>
```
    command - The command to run.
    uuid - The UUID of the container to run the command in.

The result of running the command will be displayed as if it was run directly from within the container.

### Validate a container

Validates a container's Tredlyfile to ensure it is syntactically and logically correct. Validate does everything tredly create container does with the exception of actually building the container.
```
tredly validate container [--location=<value>]
```
    --location - Specify the path to the Tredlyfile and any supporting files needed for installation. If not set, this command searches the current directory. (optional)

## Accessing the Console
```
tredly console <uuid>
```
Provides shell access into a container. console is the only subject that does not have any actions associated to it. Instead it only requires the target container UUID.

A list of container UUID values can be obtained by using "tredly list containers".

## Listing Containers and Partitions
By using the list action, it is possible to get a full list of all partitions and containers.
```
tredly list containers [<partition>]
tredly list partitions
```
    partition - Filter the list of containers by a specified partition. If it is omitted, all containers will be listed. (optional)

## Destroying All Containers
It is possible to destroy all containers in a partition by using the destroyÂ action.
```
tredly destroy containers <partition>
```
    partition - Destroy only containers in the specified partition. Use default to destroy containers that are not allocated to a specific partition.

When destroying containers, any persistent storage will be preserved.

## Destroy All Partitions and Containers
Use this command to completely destroy all partitions, all their containers, and all persistent storage.
```
tredly destroy partitions
```
All partitions will be destroyed, including the default partition. Once it is complete, the default partition is recreated.

Note that all persistent storage will also be destroyed.
