# Performs checks on the tredly-host.conf config file
from subprocess import Popen, PIPE
from includes.output import *
import subprocess

class ConfigChecks:
    
    # Constructor
    def __init__(self, filePath = '/usr/local/etc/tredly/tredly-host.conf', delimiter = '='):
        self.filePath = filePath
        self.delimiter = delimiter

    # check an option from the config file with a given value
    def checkOption(self, optionName, checkValue):
        optionValue = subprocess.getoutput('cat ' + self.filePath + ' | grep "' + optionName + self.delimiter +'"')
        return (optionValue.split(self.delimiter, 1)[-1].strip() == checkValue.strip())