# TidyCmd v0.2.0
# https://github.com/laurieodgers/tidycmd
#
# A class to abstract out calls to Popen
# Allows for easy chaining of commands akin to piping them on the command line
from subprocess import Popen, PIPE
import re
import copy

class TidyCmd:
    # cmd arg is a list
    def __init__(self, cmd):
        self.cmds = []
        self.stdOut = PIPE
        self.stdErr = PIPE

        self.returnCode = -1

        # append the list to the cmds list to create a 2d list
        self.cmds.append(cmd)

    # turns this object into a command line string
    def __str__(self):
        string = None
        
        # take a copy of the commands so that we can modify it before output
        cmdsCopy = copy.deepcopy(self.cmds)
        
        # loop over the commands
        for cmd in cmdsCopy:
            # loop over each block in the command
            for i,block in enumerate(cmd):
                # look for spaces, and add quotes if found
                if re.search(r"\s", cmd[i]):
                    # add quotes
                    cmd[i] = "'" + cmd[i] + "'"
            
            # if this isnt the first command then add a pipe character
            if (string is not None):
                string = string + ' | ' + " ".join(cmd)
            else:
                string = " ".join(cmd)
            
        return string

    # decode stdout and return a string
    def getStdOut(self, encoding='UTF-8'):
        return self.stdOut.decode(encoding).rstrip()
    
    # decode stderr and return a string
    def getStdErr(self, encoding='UTF-8'):
        return self.stdErr.decode(encoding).rstrip()

    # append a command to the chain
    def appendPipe(self, cmd):
        self.cmds.append(cmd)

    # Run the command chain
    def run(self):
        lastCmd = None
        stdIn = None

        # loop over the commands
        for cmd in self.cmds:
            # if this is not the first command then pipe stdout from the last command to stdin
            if (lastCmd is not None):
                # set the stdin for this command to be last commands stdout
                stdIn = lastCmd.stdout

            # run the command with stdin from last command
            thisCmd = Popen(cmd, stdin=stdIn, stdout=PIPE, stderr=PIPE)

            lastCmd = thisCmd

        # keep stdout, stderr and the return code
        self.stdOut, self.stdErr = thisCmd.communicate()
        self.returnCode = thisCmd.returncode

        # return stdout as a string and strip the last newline
        return self.stdOut.decode('UTF-8').rstrip()