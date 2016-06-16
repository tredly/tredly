# Performs actions requested by the user
import builtins
from subprocess import Popen, PIPE
import urllib.request
import os.path
from includes.util import *
import time
from datetime import datetime, timedelta
import shutil

from includes.defines import *
from includes.output import *
from objects.tredly.container import *
from objects.tredly.tredlyfile import *
from objects.tredly.unboundfile import *
from objects.tredly.tredlyhost import TredlyHost
from objects.layer4proxy.layer4proxyfile import *

class ActionStop():
    def __init__(self, subject, target, identifier, actionArgs):
        if (subject == "container"):
            self.stopContainer(target)
        else:
            e_error("No command " + subject + " found.")
            exit(1)

    # stop a container
    def stopContainer(self, uuid):
        startTime = time.time()
        tredlyHost = TredlyHost()
        
        ###############################
        # Start Pre flight checks
        
        # make sure the uuid exists
        if (uuid is None):
            e_error("No UUID specified.")
            exit(1)
    
        # make sure the container exists
        if (not tredlyHost.containerExists(uuid)):
            e_error("No container with UUID " + uuid + " exists.")
            exit(1)
    
        # End pre flight checks
        ###############################
        
        # find which partition this container resides on
        partitionName = tredlyHost.getContainerPartition(uuid)
        
        # load the container from ZFS
        container = Container()
        
        # set up the dataset name that contains this containers data
        containerDataset = ZFS_TREDLY_PARTITIONS_DATASET + "/" + partitionName + "/" + TREDLY_CONTAINER_DIR_NAME + "/" + uuid
        
        # make the container populate itself from zfs
        container.loadFromZFS(containerDataset)
        if (container.uuid is None):
            container.uuid = uuid
            
        zfsContainer = ZFSDataset(container.dataset, container.mountPoint)
        
        e_header("Stopping Container - " + container.name)
        
        # check if its already running
        if (not container.isRunning()):
            e_error("Container already stopped")
            exit(1)
    
        # run through the stop process
        container.stop()
    
        endTime = time.time()
        
        e_success("Stop container completed at " + time.strftime('%Y-%m-%d %H:%M:%S %z', time.localtime(endTime)))
    
        timeTaken = int(endTime) - int(startTime)
        
        # 0 seconds doesnt sound right
        if (timeTaken == 0):
            timeTaken = 1
    
        e_success("Total time taken: " + str(timeTaken) + " seconds")
