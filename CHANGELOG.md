# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [1.1.7]
#### Fixed
- Using the string "any" for in/out ports now works correctly

#### Changed
- Removed directories that were originally created under partition data directory for VUID

## [1.1.6]
#### Fixed
- Copying individual files from partition now works correctly

#### Changed
- Renamed "remotecontainers" in partition to "containers"

## [1.1.5]
#### Fixed
- Isoinstaller: remove "hostname tredly" line from tredlyinstall tredly/tredly#80
- Tredly-build: Fix issue with stdout/stderr encoding in Container.runCmd()

## [1.1.4]
#### Fixed
- Tredly-build: Changed Container.runCmd() to use temporary files instead of PIPE for stdout and stderr. Fixes tredly/tredly#60
- Tredly-build: Copy from container directory now works correctly tredly/tredly#75
- Tredly-build: Added try catch block to catch errors within layer 7 proxy file for half built/destroyed container tredly/tredly#70
- Tredly-build: Show error message when uuid not specified for "tredly-build start container" tredly/tredly#67
- Tredly-build: Ensure a defaultrelease exists for create and replace tredly/tredly#54
- Tredly: Added check to ensure partition exists before attempting to destroy containers within tredly/tredly#71

#### Added
- Tredly-libs: Added ability to select other shells for Container.createScript()
- Tredly-libs: added function TredlyHost.getContainerNameFromUUID()
- Tredly-build: Added command "tredly stop containers <partitionname>" If partitionname is blank then all containers are stopped. User will be prompt before stopping these containers.
- Tredly-libs: Added TredlyHost.containerIsRunning() and TredlyHost.getContainerNameFromUUID()

#### Changed
- Tredly-build: Better tredlyfile version error message tredly/tredly#63
- Tredly: Changed list commands to pull partition name from the full dataset name Fixes tredly/tredly#59
- Docs: Formatted ipfw.md for markdown
- Tredly: Deprecated com.tredly:partition within partitions
- Isoinstaller: Remove bsdinstall hostname - let tredly handle this fixes tredly/tredly#69
- Isoinstaller: Add bsdinstall time back in
- Tredly-libs: Moved onstop/ondestroy commands so that we can handle errors in future

## [1.1.3]
#### Changed
- Tredly-build - last hotfix did not fix the issue, so the change has been reverted.

#### Added
- tredly-parse - changes patterns in tredlyfiles. This component still requires an installer.

## [1.1.2]
#### Fixed
- Tredly-build- updated runCmd() to remove "sh -c" - fixes tredly/tredly#60

#### Changed
- Isoinstaller: use fetch instead of cp to copy files to the new ISO jail
- Tredly-build: "Running onstart command" should actually be "running oncreate command"

## [1.1.1]
#### Fixed
- Installer/tredly-cc: Fixed incorrect location/branch of tredly-cc in install.conf

## [1.1.0]
#### Added
- Tredly-build: Add "startepoch" array to ZFS for containers to track when they have been started & to facilitate the above oncreate command fix
- Tredly-libs: Added ability to process yaml config files in configfile.py
- Tredly-core: Added missing command "tredly list partition "
- Tredly-host: Container move for containers without URLs implemented (EXPERIMENTAL)
- Tredly-build: onstart and ondestroy commands implemented
- Installer: Added option for commandcenter whitelist to menu and install.conf

#### Changed
- Isoinstaller: pull from github instead of using local files (no need to release a new iso with each point release)
- Installer: removed hard coded values from rc.conf
- Installer: Move tuneables to boot.conf from sysctl.conf
- Installer: Copy base.txz etc from ISO to host to improve installation speed instead of downloading them again
- Installer: removed option to set up users within the menu. Users are now set up on the ISO install only
- Installer: menu option ordering has changed slightly
- Installer: Clear the screen when showing final installation message on production installs
- Tredly-build: json schema added onstart & ondestroy (only exec commands)
- Tredly-libs: update configfile validation with a more descriptive error message

#### Fixed
- Installer: fix tredly kernel recompile
- Installer: change renamed files to be .(epochtime) instead of .old (allows for archiving of user files)
- Installer: if tredly user is already created then modify the user. otherwise create the user
- Installer: don't reinstall if containers are currently running
- Tredly-build: only run the oncreate commands/create the onstop script on first boot of container
- Tredly-host: change variable name for function ip4_set_host_network to mitigate namespace issues
- Tredly-core: fixed init from directory

## [1.0.3]
#### Added
- Added semaphore settings to loader.conf
- Added sysv_ipc allowed = 1 to sysctl.conf
- Added use RAM only to sysctl.conf

## [1.0.2]
#### Added
Added `startepoch` array to ZFS for containers to track when they have been started & to facilitate the `onCreate` command fix

#### Changed
Changed variable name for function `ip4_set_host_network` to mitigate namespace issues
Changed tredly ISO installer to pull from github instead of using local files
If tredly user is already created then modify the user, otherwise create the user

#### Fixed
Using tredly password to set tredly user password (formerly used root password)
Fixed tredly kernel recompile
Renaming files to be `XX.(epochtime)` instead of `xx.old` (allows for archiving of user files)
Only run the `onCreate` commands and create the `onStop` script on first boot of container

## [1.0.1]
#### Fixed
- Now able to build from current working directory (#32)
- Container's partition name now being set/retrieved from ZFS correctly (#30)
- Fixed issue causing DEBUG/Error dialog notice appearing at end of installation and host to not rebooting correctly (#29)
- Fixed issue with API message not appearing at end of installation (#28)
- Fixed pathing for current working directory

#### Changed
- Standardised ZFS property name for partition name
- Standardised partition name ZFS property

## [1.0.0]
#### Added
* Added max file size check for urls
* Added container to test layer 4 proxy
* Added `configchecks.py` to check configfiles
* Added `strip()` to `subtractfrombroadcast`
* Added extra checks for partition tests
* Added note for each URL which is set up. (#11)
* Added a countdown message  for timeout
* Added option to continue with installation and confirmation
* Added timeout of 10 seconds before defaults are used and installation continues automatically.
* Added full paths to a lot of binaries for ISO install
* Added user password config
* Added `pyyml` to installer
* Added YAML tredlyfile parser (#26)
* Added more network and firewall tests
* Improved tests - converted test to python, added layer4 checks, check url redirects
* Implemented maxCpu cores

#### Changes
* Moved to testing modules
* Cleaned up partition directory if no certificates exist inside
* Setting mode `700` on SSL certificates directories in nginx
* Changes to installer messages
* Layer 7 whitelist now applies and cleans up correctly
* Remove unicode characters from bash output functions
* Update partition create/destroy to allow percentages and cores
* Update partition tests to test standard setup
* Additional check for host config commands
* Changed where time for replace is output
* Created partition now allows `ipv4whitelist` to be set
* Remove renaming of container which is being replaced. (#12)
* Change the way resource limits are displayed - add success/failed messages (#10)
* Improved installer menu -- Now has ability to hit enter for default values where one is set
* Shortened length external interface select message
* ZFS datasets are now created by installerconfig
* remove old api password retrieval and replace with set password
* Set tredly's shell to be bash
* Update `freebsd-update.conf` to not download kernel since we have a custom one
* Update bash install to set bash as shell for root and tredly users
* Update bash install to install root ca certs
* Remove redundant options from TREDLY kernel conf
* Remove debug for release
* Testing zfs config menu for ISO

## [1.0.0-rc.1]
#### Added
- "tredly config host DNS" command implemented
- Implemented sigint (ctrl-c) capture during creation and will destroy half created container
- Added persistent storage for partitions
- Added persistent storage to list command
- Commenced work on automated tests (/tests)
- Added search for "tredly.json" - the v1.0 JSON based tredlyfile

#### Changed
- Moved all bash libs and python libs to tredly-libs component
- Updated pathing for non installed scripts
- Changed Tredly config container subnet header message
- Standardised pathing for python Tredly modules
- Cleaned up repo directory structure
- Tredly-host moved to python. Tredly-host bash functionality moved to tredly command
- Changed "tredly config api all" to "tredly config api init"
- Functions which should return a value now return a value
- Tredlyfile URLs can now have the relevant protocol in the URL (http:// or https://) which is stripped before processing

#### Fixed
- Tredly-build validation now returns an error message instead of exception
- Container replace - old container will be renamed back to its original name only if it exists
- Changed ip4 tredlyfile validation and replaced with regex
- Updated Tredlyfile schema relating to 'exec_prestart', 'exec_poststart', 'exec_stop' and 'exec_prestop' technical options
- Casting children.max, 'securelevel' and 'devfs_ruleset' to integers in the 0.10 Tredlyfile parser
- Updated Tredlyfile schema - Technical options 'securelevel' now has an allowable range of -1 to 3 and 'devfs_ruleset' now allows any integer value.
- Removed use of ipv4 format validation and replaced with custom pattern as the Python json schema lib does not support the 'format' property.

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

[1.0.3]: https://github.com/tredly/tredly/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/tredly/tredly/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/tredly/tredly/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/tredly/tredly/compare/v1.0.0-rc.1...v1.0.0
[1.0.0-rc.1]: https://github.com/tredly/tredly/compare/v1.0.0-beta-160610...v1.0.0-rc.1
[1.0.0-beta - 2016-06-10]: https://github.com/tredly/tredly/compare/v1.0.0-beta-160609...v1.0.0-beta-160610
[1.0.0-beta - 2016-06-09]: https://github.com/tredly/tredly/compare/v1.0.0-beta-160606...v1.0.0-beta-160609
[1.0.0-beta - 2016-06-06]: https://github.com/tredly/tredly/compare/v1.0.0-beta...v1.0.0-beta-160606
