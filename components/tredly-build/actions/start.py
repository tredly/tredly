# Performs actions requested by the user
import builtins
from tredly.container import *
from tredly.tredlyfile import *
from tredly.unboundfile import *
from subprocess import Popen, PIPE
# import global variables
from includes.defines import *
from includes.output import *
import urllib.request
import os.path
from includes.util import *
from objects.tredly.tredlyhost import TredlyHost
import time

class ActionStart():
    def __init__(self, subject, target, identifier, actionArgs):
        if (subject == "container"):
            self.startContainer(target, actionArgs['ip4Addr'])
            
    # Start a container
    def startContainer(self, uuid, ip4Addr = None):
        startTime = time.time()
        
        ######################################
        # Start Pre Flight Checks
        tredlyHost = TredlyHost()
    
        # make sure the container exists
        if (not tredlyHost.containerExists(uuid)):
            e_error("No container with UUID " + uuid + " exists.")
            exit(1)
    
        # validate the manual ip4_addr if it was passed
        if (ip4Addr is not None):
            regex = '^(\w+)\|([\w.]+)\/(\d+)$'
            m = re.match(regex, ip4Addr)
            
            if (m is None):
                e_error('Could not validate ip4_addr "' + ip4Addr + '"' )
                exit(1)
            else:
                # assign from regex match
                interface = m.group(1)
                ip4 = m.group(2)
                cidr = m.group(3)
                
                # make sure the interface exists
                if (not networkInterfaceExists(interface)):
                    e_error('Interface "' + interface + '" does not exist in "' + ip4Addr +'"')
                    exit(1)
                # validate the ip4
                if (not isValidIp4(ip4)):
                    e_error('IP Address "' + ip4 + '" is invalid in "' + ip4Addr +'"')
                    exit(1)
                # validate the cidr
                if (not isValidCidr(cidr)):
                    e_error('CIDR "' + cidr + '" is invalid in "' + ip4Addr + '"')
                    exit(1)
    
                # make sure its not already in use
                if (ip4InUse(ip4)):
                    e_error("IP Address " + ip4 + ' is already in use.')
                    exit(1)
        
        # End Pre Flight Checks
        ######################################
    
        # set up networking
        containerIp4 = None
        containerCidr = None
        containerInterface = None
        
        # check if ip4Addr was received and process it
        if (ip4Addr is not None):
            # ip4Addr is in the form "bridge0|192.168.0.2/24"
            regex = '^(\w+)\|([\w.]+)\/(\d+)$'
            m = re.match(regex, ip4Addr)
            
            if (m is not None):
                # assign from regex match
                containerInterface = m.group(1)
                containerIp4 = m.group(2)
                containerCidr = m.group(3)
    
        # find which partition this container resides on
        partitionName = tredlyHost.getContainerPartition(uuid)
    
        # get a container object
        container = Container()
        
        # set up the dataset name that contains this containers data
        containerDataset = ZFS_TREDLY_PARTITIONS_DATASET + "/" + partitionName + "/" + TREDLY_CONTAINER_DIR_NAME + "/" + uuid
    
        # load the containers properties from ZFS
        container.loadFromZFS(containerDataset)
        if (container.uuid is None):
            container.uuid = uuid
        
        e_header("Starting Container - " + container.name + ' in partition ' + container.partitionName)
    
        if (container.isRunning()):
            e_error("Container already started")
            exit(1)
    
        e_note("Starting container " + container.name)
        # start the container
        if (container.start(containerInterface, containerIp4, containerCidr)):
            e_success("Success")
        else:
            e_error("Failed")
    
        endTime = time.time()
        
        e_success("Start container completed at " + time.strftime('%Y-%m-%d %H:%M:%S %z', time.localtime(endTime)))
    
        timeTaken = int(endTime) - int(startTime)
        
        # 0 seconds doesnt sound right
        if (timeTaken == 0):
            timeTaken = 1
        
        e_success("Total time taken: " + str(timeTaken) + " seconds")