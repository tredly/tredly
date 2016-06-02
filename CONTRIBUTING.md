# Contributing to this project

We encourage contribution to this project and only ask you follow some simple rules to make everyone's job a little easier.

**\*\* Note that some of the existing code does not confirm to these guidelines. Tredly is currently pre-v1.0, so there is some flexibility due to the rapid development that is occurring. We'd ask you still try to follow these guidelines wherever possible as they will be strictly enforced once Tredly reaches version 1.0**

## Found a bug?

Please lodge an issue at the GitHub issue tracker for this project -- <https://github.com/tredly/tredly/issues>

Include details on the behaviour you are seeing, and steps needed to reproduce the problem. Also, include details on the hardware you are running Tredly on. This will help us to better understand the problem.

## Want to contribute code?

### TL;DR - Here are the important bits

* Fork the project
* Make your feature addition or bug fix
* Ensure your code is nicely formatted
* Make sure each of the changes you are making relates to an issue.
* Commit just the modifications, do not alter CHANGELOG.md. Link to GitHub issue in your commit message (see <https://help.github.com/articles/closing-issues-via-commit-messages/>)
* Send the pull request against the `integration` branch

We will review the code and either merge it in, or leave some feedback.

### Pull requests

When issuing a pull request, please adhere to the following:

- [ ] Squash commits before sending a pull request.
- [ ] Where ever possible, separate each feature or bug fix into a separate pull request.
- [ ] Only open pull requests against the `integration` branch.
- [ ] Do not make changes to README.md, LICENCE, CONTRIBUTING.md or CHANGELOG.md


### BASH Code Style Guide

All code contributions are required to follow this code style guide.

#### General Guidelines

* Use 4 spaces instead of tabs
* Variables within functions must be declared local and use an underscore (`_var`)
* Double brackets/square brackets for everything. E.g. `if [[ something ]]; then` or `if ((a < 50)); then`

#### `IF` statements

```
if ! [[ something ]] ; then
    return $E_ERROR
fi
```

#### Functions

* Start with 'function' keyword.
* A single space before opening brace
* Use the comment block above functions

```
## Provide a good explanation here of what your function does
##
## Arguments:
##     1. String. Describe the input
##
## Usage:
##     some_function "fred" -> outputs "hello fred"
##
## Return:
##     none
function some_function() {
    ...
}
```

#### `case` statements

```
case "${_var}" in
    string)
        do stuff here
    ;;
    more)
        do other stuff
    ;;
esac
```
