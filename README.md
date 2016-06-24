# Tredly

- Version: v1.0.1
- Date: June 24 2016
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

To install Tredly, your server must be running **FreeBSD 10.3 (or above) as Root-on-ZFS**. Further details can be found at the [Tredly Docs site](http://www.tredly.com/docs/?docs=getting-started/installation).

## Installation

### Via Git

1. Follow the steps outlined here <http://www.tredly.com/docs/?docs=getting-started/installation> to install and set up your host for use with Tredly.
2. Clone the Tredly repository to the desired location (we suggest `/tmp`):
```
    git clone git://github.com/tredly/tredly.git /tmp
    cd /tmp/tredly
```
3. Finally run `./install.sh` to install.

## Configuration

Tredly can be configured in a number of ways, depending on what you are trying to achieve. We recommend you read the Tredly docs at <http://www.tredly.com/docs/?docs=getting-started> to understand the options you can configure in Tredly.

## Usage

Tredly incorporates a number of commands for manipulating partitions and their containers. To see a full list of these commands, go to the **[Tredly docs website](http://www.tredly.com/docs/?docs=getting-started/tredly-commands)**

## Container examples

You can download a number of container examples from **<https://github.com/tredly>**. These examples are there to give you a good starting point for building your own containers.

## Extending Tredly

Tredly already has the [Tredly API](https://github.com/tredly/tredly-api), which simplifies updating containers and improves scalability, and [Tredly CLI](https://github.com/tredly/tredly-cli), which provides remote access to a Tredly enabled host.

## Contributing

We encourage you to contribute to Tredly. Please check out the [Contributing documentation](https://github.com/tredly/tredly-host/blob/master/CONTRIBUTING.md) for guidelines about how to get involved.

### Technical Documentation
All technical documentation is available in `doc/`. These docs contain development information such as reserved IP addresses, reserved firewall tables, and ZFS dataset/property names.

## License

Tredly is released under the [MIT License](http://www.opensource.org/licenses/MIT).

## Other Information

Tredly example containers are available from <https://github.com/tredly>.

Tredly and its components are being actively developed. For more information please check both <https://github.com/tredly> and <https://twitter.com/tredly_com> for Tredly update notifications.
