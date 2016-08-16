# Performs actions requested by the user
import builtins
from subprocess import Popen, PIPE
import urllib.request
import os.path
import time
import argparse

from objects.tredly.tredlyhost import *
from objects.tredly.container import *
from objects.tidycmd.tidycmd import *
from includes.util import *
from includes.defines import *
from includes.output import *


# config the host
class ActionClone:
    def __init__(self, subject, target, identifier, actionArgs):
        tredlyHost = TredlyHost()

        if (len(subject) > 0):
            # clone the repo
            # subject == URL# target == destination
            self.cloneContainer(subject, actionArgs['branch'], target)

        else:
            e_error("Please include a Git URL.")
            exit(1)

    # clone a container
    def cloneContainer(self, url, branch = None, target = None):
        #### Checks:
        if ((url is None) or (len(url) == 0)):
            e_error("Please include a Git URL to clone.")
            exit(1)

        # if the target wasnt set then use the current directory
        if (target is None):
            target = './'

        # if the branch is blank then use master branch
        if (branch == None):
            branch = 'master'

        #### End checks

        e_header("Cloning repository " + url)

        e_note("Cloning branch " + branch + " into " + target)

        # clone the repo
        cmd = TidyCmd(['git', 'clone', '-b', branch, url, target])
        cmd.run()

        if (cmd.returnCode == 0):
            e_success()
        else:
            print(cmd.getStdErr())
            e_error()
            exit(1)
