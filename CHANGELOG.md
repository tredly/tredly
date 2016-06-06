# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## v1.0.0-beta - 2016-06-06
#### Added
- Start & stop for containers, a lot of code has been refactored to facilitate this

#### Changed
- Moved API installation location within tredly installer

#### Fixed
- Bugfixes for urlredirects - dns entries are now correct and clean up correctly upon container stop/destruction
- Bugfixes for ipfw in container
- Bugfix for reloading DNS on create

## v1.0.0-beta - 2016-06-02
#### Added
- Initial release of Tredly rewrite
- Single codebase (i.e. removal of seperate tredly-host and tredly-build repositories)
- Framework now written in Python 3 (many supporting libraries are still in written in BASH)
