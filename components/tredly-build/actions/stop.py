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

# destroy a container
def actionStopContainer(uuid):
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
