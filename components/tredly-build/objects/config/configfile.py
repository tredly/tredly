# A class to represent a tredly partition
import builtins
import os.path
import re
from includes.util import *
from includes.output import *

class ConfigFile:
    
    # Constructor
    def __init__(self, filePath = None):
        if (filePath is None):
            filePath = builtins.tredlyConfDirectory + "/tredly-host.conf"
            
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
            return False;
        
        # file exists so process it
        with open(self.filePath) as configFile:
            for line in configFile:
                # strip off leading and following whitespace
                line = line.strip();
                
                # if this line has data then process it
                if ((len(line) > 0) and (not line.startswith('#'))):
                    key, value = line.partition("=")[::2];
                    
                    # populate only if there was a value
                    if (len(value) > 0):
                        # populate our variables
                        if (key == "required"):
                            # split out the required values
                            values = value.split(',')
                            # strip any whitespace
                            map(str.strip, values)
                            
                            self.required = values;
                        
                        elif (key == "wif"):
                            self.wif = value;
                        
                        elif (key == "lif"):
                            self.lif = value;
                        
                        elif (key == "wifPhysical"):
                            self.wifPhysical = value;
                        
                        elif (key == "lifNetwork"):
                            values = value.split('/')
                            # split it into network and cidr
                            self.lifNetwork = values[0]
                            self.lifCIDR = values[1]
                        
                        elif (key == "dns"):
                            self.dns.append(value);
                        
                        elif (key == "httpproxy"):
                            self.httpProxyIP = value;
                        
                        elif (key == "tld"):
                            self.tld = value;
                        
                        elif (key == "vnetdefaultroute"):
                            self.vnetDefaultRoute = value;
                            
                        elif (key == "firewallEnableLogging"):
                            self.firewallEnableLogging = value;
                        else:
                            e_warning("Unrecognised config definition: " + line);
        
        return True
    
    # Action: checks whether the path to the tredlyfile exists or not
    #
    # Pre: 
    # Post: 
    #
    # Params: 
    #
    # Return: True if exists, False otherwise
    def fileExists(self):
        return os.path.isfile(self.filePath);

    # Action: validates this object
    #
    # Pre: this object exixsts
    # Post: 
    #
    # Params: required - list of required fields
    #
    # Return: True if valid, False otherwise
    def validate(self, requiredList = []):
        # join the two required lists together
        requiredList = requiredList
        
        for required in requiredList:
            # TODO: re-implement this with json/dicts
            if (required == "wif"):
                if (len(self.wif) == 0):
                    return False
            elif (required == "lif"):
                if (len(self.lif) == 0):
                    return False
            elif (required == "wifPhysical"):
                if (len(self.wifPhysical) == 0):
                    return False
            elif (required == "lifNetwork"):
                if (len(self.lifNetwork) == 0):
                    return False
            elif (required == "dns"):
                if (len(self.dns) == 0):
                    return False
            elif (required == "httpproxyip"):
                if (len(self.httpProxyIP) == 0):
                    return False
            elif (required == "tld"):
                if (len(self.tld) == 0):
                    return False
            elif (required == "vnetdefaultroute"):
                if (len(self.vnetDefaultRoute) == 0):
                    return False
            elif (required == "firewallEnableLogging"):
                if (len(self.firewallEnableLogging) == 0):
                    return False

        # make sure network interfaces exist
        if (not networkInterfaceExists(self.wif)):
            e_error('Interface "' + self.wif + '" does not exist in "tredly-host.conf"')
            return False
        if (not networkInterfaceExists(self.lif)):
            e_error('Interface "' + self.lif + '" does not exist in "tredly-host.conf"')
            return False
        if (not networkInterfaceExists(self.wifPhysical)):
            e_error('Interface "' + self.wifPhysical + '" does not exist in "tredly-host.conf"')
            return False
        
        # everything passed, so return true
        return True
        