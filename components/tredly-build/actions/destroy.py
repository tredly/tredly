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
from objects.layer4proxy.layer4proxyfile import *
from datetime import datetime, timedelta

# destroy a container
def actionDestroyContainer(uuid, partitionName = None):
    tredlyHost = TredlyHost()
    
    ###############################
    # Start Pre flight checks
    
    # make sure the uuid exists
    if (uuid is None):
        e_error("No UUID specified.")
        exit(1)

    # if the partition name wasnt given then find it
    if (partitionName is None):
        # find the container with uuid
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
    e_note("Destroying container " + str(container.name))
    if (container.destroy()):
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
