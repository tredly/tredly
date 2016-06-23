# Performs network checks
from subprocess import Popen, PIPE
from includes.output import *

class FirewallChecks:
    
    # Constructor
    def __init__(self, uuid = None):
        # if uuid == None then check the host
        self.uuid = uuid

    def checkIpfwRule(self, permission, fromIP, toIP, toPort, direction):
        cmd = ['ipfw', 'list']
        
        # add the jexec command if we're dealing with a container
        if (self.uuid is not None):
            cmd = ['jexec', 'trd-' + self.uuid] + cmd
        
        process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
        stdOut, stdErr = process.communicate()
        stdOutString = stdOut.decode('utf-8')
        stdErrString = stdErr.decode('utf-8')
        
        for line in stdOutString.splitlines():
            words = line.split()
            
            # chcek against this line
            if (words[1] == permission) and (words[7] == fromIP) and (words[9] == toIP) and (words[11] == toPort):
                return True
        
        return False
    # checks that a value exists in an ipfw table
    def checkIpfwTable(self, tableNum, value):
        cmd = ['ipfw', 'table',str(tableNum), 'list']
        
        # add the jexec command if we're dealing with a container
        if (self.uuid is not None):
            cmd = ['jexec', 'trd-' + self.uuid] + cmd

        process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
        stdOut, stdErr = process.communicate()
        stdOutString = stdOut.decode('utf-8')
        stdErrString = stdErr.decode('utf-8')

        if (process.returncode != 0):
            e_error("Failed to check ipfw table")
            print(stdOutString)
            print(stdErrString)
            print('exitcode: ' + process.returncode)
            exit(process.returncode)

        # loop over the lines looking for our value
        for line in stdOutString.splitlines():
            if (line.split()[0] == value):
                return True
        
        return False
    
