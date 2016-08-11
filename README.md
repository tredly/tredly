# Tredly

- Version: v1.1.8
- Date: August 11 2016
- [Release notes](https://github.com/tredly/tredly/blob/master/CHANGELOG.md)
- [GitHub repository](https://github.com/tredly/tredly)

## Overview

Tredly is a suite of products to enable developers to spend less time on sysadmin tasks and more time developing. Tredly is a full stack container solution for FreeBSD. It has two main components: Host and Build.

### Host

The server technology used to run the containers, built on FreeBSD. It contains a number of inbuilt features:

  * Layer 7 Proxy (HTTP/HTTPS proxy)
  * Layer 4 Proxy (TCP/UDP Proxy)
  * DNS

### Build

Validates and manages containers on a Tredly enabled Host

You can find out more information about Tredly at **<http://www.tredly.com>**

## Requirements

To install Tredly, your server must be running **FreeBSD 10.3 (or above) as Root-on-ZFS**. Further details can be found in INSTALLATION.md.

## Installation

### Via Git

1. Follow the steps outlined within INSTALLATION.md to install and set up your host for use with Tredly.
2. Clone the Tredly repository to the desired location (we suggest `/tmp`):

    ```
        git clone git://github.com/tredly/tredly.git /tmp
        cd /tmp/tredly
    ```
3. Finally run `./install.sh` to install.

### Via ISO

A full FreeBSD and Tredly installation ISO can be downloaded from <https://s3-us-west-2.amazonaws.com/tredly-isos/Tredly-1.1-RELEASE-amd64.iso>

## Documentation

All documentation can be found under the /doc directory - (https://github.com/tredly/tredly-host/blob/master/doc/)

## Configuration

Tredly can be configured in a number of ways, depending on what you are trying to achieve. We recommend you read (https://github.com/tredly/tredly-host/blob/master/CONFIGURING.md) to understand the options you can configure in Tredly.

## Usage

Tredly incorporates a number of commands for manipulating partitions and their containers. To see a full list of these commands, read (https://github.com/tredly/tredly-host/blob/master/doc/commands.md)

## Container examples

You can download a number of container examples from **<https://github.com/tredly>**. These examples are there to give you a good starting point for building your own containers.

## Extending Tredly

Tredly already has a number of extensions:
1. [Tredly API](https://github.com/tredly/tredly-api), which simplifies updating containers and improves scalability
2. [Tredly CLI](https://github.com/tredly/tredly-cli), which provides remote CLI access to the tredly commands on a Tredly enabled host
3. [Tredly Command Center](https://github.com/tredly/tredly-cc), which provides a web based GUI to manage your host

## Contributing

We encourage you to contribute to Tredly. Please check out the [Contributing documentation](https://github.com/tredly/tredly-host/blob/master/CONTRIBUTING.md) for guidelines about how to get involved.

### Technical Documentation

All technical documentation is available in `doc/development`. These docs contain development information such as reserved IP addresses, reserved firewall tables, and ZFS dataset/property names.

## License

Tredly is released under the [MIT License](http://www.opensource.org/licenses/MIT).

## Other Information

Tredly example containers are available from <https://github.com/tredly>.

Tredly and its components are being actively developed. For more information please check both <https://github.com/tredly> and <https://twitter.com/tredly_com> for Tredly update notifications.
