# A class to represent a tredly partition
import builtins
import os.path
import re
import yaml

from includes.util import *
from includes.output import *

class ConfigFile:

    # Constructor
    def __init__(self, filePath = None):
        if (filePath is None):
            filePath = builtins.tredlyConfDirectory + "/tredly-host.conf"

        # TODO: the following is deprecated and will be removed in a future release
        self.filePath = filePath
        self.required = []
        self.wif = None
        self.lif = None
        self.wifPhysical = None
        self.lifNetwork = None
        self.lifCIDR = None
        self.dns = []
        self.httpProxyIP = None
        self.tld = None
        self.vnetDefaultRoute = None
        self.firewallEnableLogging = None

        # for YAML
        self.json = None

    # Action: process a config file - populates this class
    #
    # Pre:
    # Post: Config file has been processed
    #
    # Params:
    #
    # Return: True if succeeded, False otherwise
    def process(self):
        # check if the file exists at the given path
        if (not self.fileExists()):
            e_error("Config file " + self.filePath + " does not exist.")
            return False

        # file exists so process it
        with open(self.filePath) as configFile:
            for line in configFile:
                # strip off leading and following whitespace
                line = line.strip()

                # if this line has data then process it
                if ((len(line) > 0) and (not line.startswith('#'))):
                    key, value = line.partition("=")[::2]

                    # populate only if there was a value
                    if (len(value) > 0):
                        # populate our variables
                        if (key == "required"):
                            # split out the required values
                            values = value.split(',')
                            # strip any whitespace
                            map(str.strip, values)

                            self.required = values

                        elif (key == "wif"):
                            self.wif = value

                        elif (key == "lif"):
                            self.lif = value

                        elif (key == "wifPhysical"):
                            self.wifPhysical = value

                        elif (key == "lifNetwork"):
                            values = value.split('/')
                            # split it into network and cidr
                            self.lifNetwork = values[0]
                            self.lifCIDR = values[1]

                        elif (key == "dns"):
                            self.dns.append(value)

                        elif (key == "httpproxy"):
                            self.httpProxyIP = value

                        elif (key == "tld"):
                            self.tld = value

                        elif (key == "vnetdefaultroute"):
                            self.vnetDefaultRoute = value

                        elif (key == "firewallEnableLogging"):
                            self.firewallEnableLogging = value
                        else:
                            e_warning("Unrecognised config definition: " + line)

        return True

    # Action: parses a YAML config file
    #
    # Pre:
    # Post: this object has been populated with data from the config file
    #
    # Params:
    #
    # Return: True if exists, False otherwise
    def processYaml(self):
        file = open(self.filePath, 'r')

        self.json = yaml.load(file.read())

    # Action: checks whether the path to the tredlyfile exists or not
    #
    # Pre:
    # Post:
    #
    # Params:
    #
    # Return: True if exists, False otherwise
    def fileExists(self):
        return os.path.isfile(self.filePath)

    # TODO: validate YAML

    # Action: validates this object
    #
    # Pre: this object exixsts
    # Post:
    #
    # Params:
    #
    # Return: True if valid, False otherwise
    def validate(self):
        if (self.wif is None):
            return False

        if (self.lif is None):
            return False

        if (self.wifPhysical is None):
            return False

        if (self.lifNetwork is None):
            return False

        if (self.dns is None):
            return False

        if (self.httpProxyIP is None):
            return False

        if (self.tld is None):
            return False

        if (self.vnetDefaultRoute is None):
            return False

        if (self.firewallEnableLogging is None):
            return False

        # make sure network interfaces exist
        if (not networkInterfaceExists(self.wif)):
            e_error('Interface "' + self.wif + '" from "tredly-host.conf" does not exist on this host.')
            return False
        if (not networkInterfaceExists(self.lif)):
            e_error('Interface "' + self.lif + '" from "tredly-host.conf" does not exist on this host.')
            return False
        if (not networkInterfaceExists(self.wifPhysical)):
            e_error('Interface "' + self.wifPhysical + '" from "tredly-host.conf" does not exist on this host.')
            return False

        # everything passed, so return true
        return True
