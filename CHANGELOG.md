# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [1.0.0-beta - 2016-06-10]
#### Added
- Now importing actions as modules. Allows for "drop in" commands in the same style as the bash tredly-build code
- Added "tredly command container" wrapper for jexec
- Added static ip network setup

#### Changed
- Major structural change to files and libraries
- Change exit code for sigint

#### Fixed
- Don't register URLs if there were no URLs
- Bug fix for bash container_exists
- Fix bugs with config menu on installer
- Fix missing Tredly-cc URL config menu option

## [1.0.0-beta - 2016-06-09]
### HOST
#### Added
- `fail2ban` implemented on host port 65222 tcp (SSH)
- Added Tredly command center to host installer
- Added flag to installer config file to allow set up of SSHd, tredly-api and tredly-cc
- Automatically whitelist Tredly command center
- Added static ips config file
- Added Tredly command centre URL in installer

#### Changed
- Moved location of `tredly-api` and `tredly-cc` within installer
- Installer now fetches kernel source from HTTPS instead of HTTP

### BUILD
#### Added
- `url1ErrorResponse` setting added to layer7Proxy. Defaults to yes. When set to 'yes', the layer7proxy will send the error page. When set to 'no' the container's error page is used instead.
- It is now possible to build container from a remote path using `--path=` to create or replace. _Note that `--path=` will change to `--location=` in the next release_

#### Changed
- Refactored `tredly-build container replace` to use objects instead of using the create/destroy methods.
- layer7Proxy url values are now overwritten with the new container's values upon replace
- nginx cleanup code upon stop now makes use of JSON objects from ZFS
- Automatic redirect from http -> https is populated into the url redirects object from Tredlyfile.
- `tredlyhost.getContainersWithArray()` now returns a unique set() instead of a list
- JSON schema updated so that `urlCert` is set to None when not present in the Tredlyfile. This applies redirects also.
- A redirect URL must have a certificate set if it uses https. Likewise, there must not be a certificate set when using http.

#### Fixed
- Fixed issue with "any" rules not being applied on containers with no `ip4Whitelist` and no `containerGroup`
- Fixed bug in `fileFolderMapping` where part of the path would be truncated when copying data from partition

### CORE
#### Added
- Added command `tredly api password` to set api password
- Implemented `tredly status` command. Shows information for the following: `api`, `commandcenter`, `dns`, `layer7proxy`

#### Changed
- Updated `tredly init` to fetch sources from HTTPS instead of HTTP

## [1.0.0-beta - 2016-06-06]
#### Added
- Start & stop for containers, a lot of code has been refactored to facilitate this

#### Changed
- Moved API installation location within Tredly installer

#### Fixed
- Bugfixes for urlredirects - DNS entries are now correct and clean up correctly upon container stop/destruction
- Bugfixes for ipfw in container
- Bugfix for reloading DNS on create

## 1.0.0-beta - 2016-06-02
#### Added
- Initial release of Tredly rewrite
- Single codebase (i.e. removal of seperate tredly-host and tredly-build repositories)
- Framework now written in Python 3 (many supporting libraries are still in written in BASH)

[1.0.0-beta - 2016-06-10]: https://github.com/tredly/tredly/compare/v1.0.0-beta-160609...v1.0.0-beta-160610
[1.0.0-beta - 2016-06-09]: https://github.com/tredly/tredly/compare/v1.0.0-beta-160606...v1.0.0-beta-160609
[1.0.0-beta - 2016-06-06]: https://github.com/tredly/tredly/compare/v1.0.0-beta...v1.0.0-beta-160606
