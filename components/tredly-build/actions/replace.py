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
import shutil

from actions.create import *
from actions.destroy import *

# destroy a container
def actionReplaceContainer(containerName, uuidToReplace, partitionName, tredlyFilePath, ip4Addr = None):
    tredlyHost = TredlyHost()
    
    ###############################
    # Start Pre flight checks
    
    if (partitionName is None):
        e_error("Please include a partition name.")
        exit(1)
        
    if (tredlyFilePath is None):
        e_error("Please specify the path of the new container")
        exit(1)
        
    # validate the manual ip4_addr if it was passed
    if (ip4Addr is not None):
        # validate it
        if (not validateIp4Addr(ip4Addr)):
            exit(1)
    
    # End pre flight checks
    ###############################
    
    # process the tredlyfile
    builtins.tredlyFile = TredlyFile(tredlyFilePath + "/Tredlyfile")
    pprint(builtins.tredlyFile.parser.read())
    # set the new container name'
    if (containerName is None):
        # get from tredlyfile
        newContainerName = builtins.tredlyFile.json['container']['name']
    else:
        newContainerName = containerName
    
    # find the uuid of container to replace if it wasnt set
    if (uuidToReplace is None):
        # no uuid received
        oldContainerUUID = tredlyHost.getUUIDFromContainerName(partitionName, newContainerName)
    else:
        oldContainerUUID = uuidToReplace
    
    # check if old container exists or not
    if (not tredlyHost.containerExists(oldContainerUUID, partitionName)):
        e_header("Replacing Container " + newContainerName)
        e_note("Container to replace does not exist")
    else:
        # get the old container name
        oldContainerDataset = ZFS_TREDLY_PARTITIONS_DATASET + '/' + partitionName + '/' + TREDLY_CONTAINER_DIR_NAME + '/' + oldContainerUUID
        zfsOldContainer = ZFSDataset(oldContainerDataset)
        oldContainerName = zfsOldContainer.getProperty(ZFS_PROP_ROOT + ':containername')
        
        e_header("Replacing Container " + oldContainerName + " with " + newContainerName)
        
        # change the name of the old container
        if (not zfsOldContainer.setProperty(ZFS_PROP_ROOT + ':containername', oldContainerName + '-REPLACING')):
            e_error("Failed to rename old container")
        
        if (not zfsOldContainer.setProperty(ZFS_PROP_ROOT + ':containerstate', 'replacing')):
            e_error("Failed to set container state")
        
    
    # create the container
    actionCreateContainer(newContainerName, partitionName, tredlyFilePath, ip4Addr, True)

    
    # destroy the old container if it exists on this partition
    if (tredlyHost.containerExists(oldContainerUUID, partitionName)):
        actionDestroyContainer(oldContainerUUID)