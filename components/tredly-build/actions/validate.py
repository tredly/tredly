# Performs actions requested by the user
import builtins
from subprocess import Popen, PIPE
import urllib.request
import os.path
import time
from datetime import datetime, timedelta

from objects.tredly.container import *
from objects.tredly.tredlyfile import *
from objects.tredly.unboundfile import *
from objects.layer4proxy.layer4proxyfile import *
from objects.tredly.tredlyhost import TredlyHost
from includes.util import *
from includes.defines import *
from includes.output import *

class ActionValidate:
    def __init__(self, subject, target, identifier, actionArgs):
        # check the subject of this action
        if (subject == "container"):
            self.validateContainer(actionArgs['path'])
        else:
            e_error("No command " + subject + " found.")
            exit(1)

    # validate a container
    def validateContainer(self, tredlyFilePath):
        # Process the tredlyfile
        builtins.tredlyFile = TredlyFile(tredlyFilePath)
        
        e_header("Validating " + tredlyFilePath + "/Tredlyfile")
        
        # validate it
        if (tredlyFile.validate()):
            e_success("Successfully validated " + tredlyFilePath + "/Tredlyfile")
        else:
            print('')
            e_error("Failed to validate " + tredlyFilePath + "/Tredlyfile")
            exit(1)