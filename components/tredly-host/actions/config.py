# Performs actions requested by the user
import builtins
from subprocess import Popen, PIPE
import urllib.request
import os.path
import time
import argparse

from objects.tredly.tredlyhost import *
from objects.tredly.resolvconffile import *
from includes.util import *
from includes.defines import *
from includes.output import *

# config the host
class ActionConfig:
    def __init__(self, subject, target, identifier, actionArgs):
        tredlyHost = TredlyHost()

        # check the subject of this action
        if (subject == "host"):
            if (target == "DNS"):
                # split out the identifier args into an array and pass to configDNS
                self.configHostDNS([builtins.tredlyCommonConfig.tld], [x.strip() for x in identifier.split(',')])
            else:
                e_error("No command " + target + " found.")
                exit(1)
        else:
            e_error("No command " + subject + " found.")
            exit(1)

    # set the resolv.conf file
    # takes 2 lists
    def configHostDNS(self, searchList, dnsList):
        e_header("Setting Host DNS")
        #############
        # Pre flight checks

        # make sure the given values are valid ips
        for host in dnsList:
            if (not isValidIp4(host)):
                e_error(host + " is not a valid IP4.")
                exit(1)

        # make sure search list is valid hostnames
        for domain in searchList:
            if (not isValidHostname(domain)):
                e_error(host + " is not a valid hostname.")
                exit(1)

        # Pre flight checks
        #############

        # create a resolvconf object
        resolvConf = ResolvConfFile('/etc/resolv.conf')

        resolvConf.search = searchList
        resolvConf.nameservers = dnsList

        # show the user what we are inserting
        e_note("search: " + ", ".join(searchList))
        e_note("nameservers: " + ", ".join(dnsList))

        if (resolvConf.write()):
            e_success("Success")
        else:
            e_error("Failed")
