# A class to represent a list of ipfw rules and tables
import os.path
from subprocess import Popen, PIPE
import builtins
import glob

from includes.output import *
from includes.util import *
from includes.defines import *

class IPFW:
    
    # Constructor
    def __init__(self, directory, uuid = None):
        self.directory = directory.rstrip('/')
        self.uuid = uuid
        self.ipfwFile = "ipfw.rules"
        self.rules = {}    # a dict of rules, keyed by rule number
        self.tables = {}   # a dict of tables, keyed by table number

    # Action: adds a rule to allow a port(s)
    #
    # Pre: this object exists
    # Post: a new rule has been added to this object
    #
    # Params:    direction - IN/OUT
    #            protocol - the protocol to allow
    #            interface - the interface to apply the rule to
    #            sourceIP - the source IP address
    #            destIP - the destination IP address
    #            ports - the ports to allow
    #            ruleNum - the rule number to add this at
    #
    # Return: True if succeeded, False otherwise
    def openPort(self, direction, protocol, interface, sourceIP, destIP, ports, ruleNum = None):
        # if rulenum is none then append to the end
        if (ruleNum is None) and (len(self.rules) > 0):
            
            maxRule = max(self.rules.keys(), key=int)

            ruleNum = int(maxRule) + 1
        else:
            ruleNum = 1
        
        # if the # of ports is 0 then dont add a rule and return
        if (ports is None) or (len(ports) == 0):
            return True
        else:
            portsCSV = ','.join(str(port) for port in ports)
        
        # Check if the user wanted direction of "any"
        if (direction == "any"):
            direction = ''
        
        # add some options if proto == tcp
        options = ''
        if (protocol == 'tcp'):
            options = "setup keep-state"
        elif (protocol == 'udp'):
            options = "keep-state"
            

        logging = ''
        if (builtins.tredlyCommonConfig.firewallEnableLogging == "yes"):
            logging = "log logamount 5"
        
        # append the rule
        self.rules[ruleNum] = "allow " + logging + " " + protocol + " from " + sourceIP + " to " + destIP + " " + portsCSV + " " + direction + " via " + interface + " " + options

    # Action: apply firewall rules
    #
    # Pre: this object exists
    # Post: ipfw rules have been applied to container or host
    #
    # Params: 
    #
    # Return: True if succeeded, False otherwise
    def apply(self):
        # write the tables out first
        for tableNum, tableList in self.tables.items():
            filePath = self.directory + "/ipfw.table." + str(tableNum)

            # open the table file for writing
            with open(filePath, "w") as ipfw_table:
                print('#!/usr/bin/env sh', file=ipfw_table)

                # loop over the list, adding the values
                for value in tableList:
                    # print the table rule to the file
                    print("ipfw table " + str(tableNum) + " add " + value, file=ipfw_table)

            # Set the permissions on this file to 700
            os.chmod(filePath, 0o700)
            
            # set up the list command
            listCmd = ['ipfw', 'table', str(tableNum), 'list']
            if (self.uuid is not None):
                # handle the container command
                listCmd = ['jexec', 'trd-' + self.uuid] + listCmd

            # get a list of live tables and remove the ips that arent associated with this object
            
            process = Popen(listCmd, stdin=PIPE, stdout=PIPE, stderr=PIPE)
            stdOut, stdErr = process.communicate()
            if (process.returncode != 0):
                e_error("Failed to list table " + str(tableNum))
            
            stdOutString = stdOut.decode(encoding='UTF-8')

            # loop over results
            for line in stdOutString.splitlines():
                # extract the value
                value = line.split()[0]
                
                # check if it exists in the table
                if (value not in self.tables[tableNum]):
                    # doesnt exist so remove it
                    if (self.uuid is None):
                        delCmd = ['ipfw', 'table', str(tableNum), 'delete', value]
                    else:
                        delCmd = ['jexec', 'trd-' + self.uuid, 'sh', '-c', 'ipfw table ' + str(tableNum) + ' delete ' + value]
                    
                    process = Popen(delCmd, stdin=PIPE, stdout=PIPE, stderr=PIPE)
                    stdOut, stdErr = process.communicate()
                    if (process.returncode != 0):
                        print(delCmd)
                        e_error("Failed to delete value " + value)
            
            # apply the table by running the script
            file = '/usr/local/etc/ipfw.table.' + str(tableNum)
            if (self.uuid is not None):    # its a container
                cmd = ['jexec', 'trd-' + self.uuid, file]
            else:                       # its the host so just run the script
                cmd = [file]
            
            process = Popen(cmd, stdin=PIPE, stdout=PIPE, stderr=PIPE)
        
            stdOut, stdErr = process.communicate()
            # return code of 0 == success
            # return code of 71 == firewall rule already exists
            if (process.returncode != 0) and (process.returncode != 71):
                e_error("Failed to apply firewall rules from " + file)
                e_error("Return code " + str(process.returncode))
                return False
        
        # now write the main rules
        filePath = self.directory + "/ipfw.rules"
        # dont overwrite the hosts ipfw rules
        if (self.uuid is not None):
            with open(filePath, "w") as ipfw_rules:
                # add the shebang
                print('#!/usr/bin/env sh', file=ipfw_rules)
                
                # loop over the tables, including them
                for tableNum, tableList in self.tables.items():
                    print('source /usr/local/etc/ipfw.table.' + str(tableNum), file=ipfw_rules)
                    
                # loop over the rules, adding them to the ipfw file
                for ruleNum, rule in self.rules.items():
                    print("ipfw add " + str(ruleNum) + " " + rule, file=ipfw_rules)
                
            
            # Set the permissions on this file to 700
            os.chmod(self.directory + '/' + self.ipfwFile, 0o700)
            
            # run the ipfw rules within the container only - host rules never change
            if (self.uuid is not None):    # its a container
                cmd = ['jexec', 'trd-' + self.uuid, '/usr/local/etc/ipfw.rules']
    
                process = Popen(cmd, stdin=PIPE, stdout=PIPE, stderr=PIPE)
                
                stdOut, stdErr = process.communicate()
                if (process.returncode != 0):
                    e_error("Failed to apply firewall rules from " + self.directory + '/' + self.ipfwFile)
                    return False
        
        # everything succeeded, return true
        return True
    
    # Action: read firewall rules
    #
    # Pre: this object exists
    # Post: ipfw rules and tables have been read from self.directory + '/' to this object
    #
    # Params: 
    #
    # Return: True if succeeded, False otherwise
    def readRules(self):
        # get a list of tables to read
        tables = glob.glob(self.directory.rstrip('/') + "/ipfw.table.*")
        
        # loop over the tables, and read each file
        for table in tables:
            # read the file
            with open(table) as ipfwTableFile:
                for line in ipfwTableFile:
                    # strip off leading and following whitespace
                    line = line.strip()
                    
                    # ignore commented lines
                    if (not line.startswith('#')) and (len(line) > 0):
                        # extract the table number and ip/range
                        tableNum = int(line.split()[2])
                        value = line.split()[4]
                        
                        # add to the list
                        self.appendTable(tableNum, value)
        # ignore main ipfw file for host
        if (self.uuid is not None):
            # now read the main ipfw file
            try:
                with open(self.directory + '/ipfw.rules') as ipfwTableFile:
                    for line in ipfwTableFile:
                        # strip off leading and following whitespace
                        line = line.strip()
                        # we're only concerned with ipfw rules, nothing else
                        if (line.startswith('ipfw')):
                            # extract the rule number - split 3 times so we can get the rule to add to our dict
                            lineParts = line.split(' ', 3)
        
                            # get hte rule number
                            ruleNum = lineParts[2]
                            
                            # append the rule
                            self.rules[ruleNum] = lineParts[3]
            except FileNotFoundError:
                e_warning("IPFW file " + self.directory + '/ipfw.rules not found.')
                return False
        
        return True
    
    
    # Action: appends a value to a given table
    #
    # Pre: this object exists
    # Post: tableNum has been updated with value
    #
    # Params: tableNum - the table number to update
    #         value - the value to update it with
    #
    # Return: True if succeeded, False otherwise
    def appendTable(self, tableNum, value):
        # if the table isnt set then set it as a list
        if (tableNum not in self.tables):
            self.tables[tableNum] = []

        # check if its an ip address and doesnt contain a /
        if (isValidIp4(value)) and ('/' not in value):
            # it is so assume its a host
            value = value + '/32'

        # check if this is already set
        if (value not in self.tables[tableNum]):
            # append the value
            self.tables[tableNum].append(value)
        
        return True
    
    # Action: remove a value from a given table
    #
    # Pre: this object exists
    # Post: value has been removed from table tableNum
    #
    # Params: tableNum - the table number to remove from
    #         values - the value to remove
    #
    # Return: True if succeeded, False otherwise
    def removeFromTable(self, tableNum, value):
        # if the table doesnt exist return false
        if (tableNum not in self.tables):
            return False

        # check if its an ip address and doesnt contain a /
        if (isValidIp4(value)) and ('/' not in value):
            # it is so assume its a host
            value = value + '/32'

        # check if the value exists
        if (value in self.tables[tableNum]):
            # remove the value
            self.tables[tableNum].remove(value)
        
        return True