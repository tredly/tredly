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

class ActionDestroy:
    def __init__(self, subject, target, identifier, actionArgs):
        # check the subject of this action
        if (subject == "container"):
            self.destroyContainer(target)
        else:
            e_error("No command " + subject + " found.")
            exit(1)
        
    # Destroy a container
    def destroyContainer(self, uuid):
    
        tredlyHost = TredlyHost()
        
        ###############################
        # Start Pre flight checks
        
        # make sure the uuid exists
        if (uuid is None):
            e_error("No UUID specified.")
            exit(1)
    
        # find which partition this container resides on
        partitionName = tredlyHost.getContainerPartition(uuid)
    
        # and the partition name
        if (partitionName is None):
            e_error("The container " + uuid + " was not found on any partition.")
            exit(1)
            
        # make sure the container exists
        if (not tredlyHost.containerExists(uuid, partitionName)):
            e_error("Could not find container with UUID " + uuid + " on partition " + partitionName)
            exit(1)
    
        # End pre flight checks
        ###############################
        
        # load the container from ZFS
        container = Container()
        
        # set up the dataset name that contains this containers data
        containerDataset = ZFS_TREDLY_PARTITIONS_DATASET + "/" + partitionName + "/" + TREDLY_CONTAINER_DIR_NAME + "/" + uuid
        
        # make the container populate itself from zfs
        container.loadFromZFS(containerDataset)
        # make sure the uuid is populated
        if (container.uuid is None):
            container.uuid = uuid
        
        zfsContainer = ZFSDataset(container.dataset, container.mountPoint)
        startDestructEpoch = int(time.time())
        
        e_header("Destroying Container - " + container.name)
        e_note("Destruction started at " + time.strftime('%Y-%m-%d %H:%M:%S %z', time.localtime(startDestructEpoch)))
        
        # check if IP exists
        try:
            e_note(container.name + " has IP address " + str(container.containerInterfaces[0].ip4Addrs[0]))
        except:
            e_warning("Container does not have an IP address")
        
        # run through the stop process
        container.stop()
    
        # destroy the container
        destroyResult = container.destroy()
        e_note("Destroying container " + str(container.name))
        if (destroyResult):
            e_success("Success")
        else:
            e_error("Failed")
        
        endEpoch = time.time()
        
        e_success("Destruction completed at " + time.strftime('%Y-%m-%d %H:%M:%S %z', time.localtime(endEpoch)))
        
        # ensure we have a valid value before attempting math or display to user
        if (container.buildEpoch is not None):
            uptimeEpoch = int(endEpoch) - int(container.buildEpoch)
            uptimeMins, uptimeSecs = divmod(uptimeEpoch, 60)
            uptimeHours, uptimeMins = divmod(uptimeMins, 60)
            uptimeDays, uptimeHours = divmod(uptimeHours, 24)
            
            e_success("Container uptime: " + str(uptimeDays) + " days " + str(uptimeHours) +" hours " + str(uptimeMins) + " minutes " + str(uptimeSecs) + " seconds")
        
        destructTime = int(endEpoch) - int(startDestructEpoch)
        
        # 0 seconds doesnt sound right
        if (destructTime == 0):
            destructTime = 1
            
        e_success("Total time taken: " + str(destructTime) + " seconds")
