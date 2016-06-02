#!/bin/sh

# get the directory where this script is located
_DIR=$( dirname `pwd`/${0} )

# include the vars shared between this and the bash script
. ${_DIR}/tredly-install/install.vars.sh

# make sure this user is root
euid=$( id -u )
if test $euid != 0
then
   echo "Please run this installer as root." 1>&2
   exit 1
fi

# force an update on pkg in case the cache is out of date and bash install fails
pkg update -f

# install bash before invoking the bash installer
pkg install -y bash

if test $? != 0
then
    echo "Failed to Download Bash"
    exit 1
fi

# run the bash installer
${_DIR}/tredly-install/bash_install.sh

if test $? != 0
then
    echo -e "\e[35m"
    echo "=================================================="
    echo "An error occurred during tredly-host installation."
    echo "=================================================="
    echo -e "\e[39m"
fi
