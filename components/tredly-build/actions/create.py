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

# Create a container
def actionCreateContainer(containerName, partitionName, tredlyFilePath, ip4Addr = None, ignoreExisting = False):
    ######################################
    # Start Pre Flight Checks
    tredlyHost = TredlyHost()

    # make sure the Tredlyfile exists
    if (not os.path.isfile(tredlyFilePath + "/Tredlyfile")):
        e_error("Could not find Tredlyfile at " + tredlyFilePath)
        exit(1)

    # Process the tredlyfile
    builtins.tredlyFile = TredlyFile(tredlyFilePath + "/Tredlyfile")
    
    # allow containername to be overridden
    if (containerName is None):
        containerName = builtins.tredlyFile.json['container']['name']

    # make sure the partition exists
    partitionNames = tredlyHost.getPartitionNames()
    if (partitionName not in partitionNames):
        e_error('Partition "' + partitionName + '" does not exist.')
        exit(1)
    
    # make sure a default release is set in zfs
    zfsTredly = ZFSDataset(ZFS_TREDLY_DATASET)
    defaultRelease = zfsTredly.getProperty(ZFS_PROP_ROOT + ':default_release_name')
    
    if (defaultRelease == '-') or (defaultRelease is None) or (len(defaultRelease) == 0):
        e_error('Please set a default release to use with "tredly modify defaultRelease".')

    # validate the manual ip4_addr if it was passed
    if (ip4Addr is not None):
        # validate it
        if (not validateIp4Addr(ip4Addr)):
            exit(1)

    # make sure a container with this name on this partition doesnt already exist
    # if we werent told to ignore existing
    if (tredlyHost.getUUIDFromContainerName(partitionName, containerName) is not None) and (not ignoreExisting):
        e_error("Container with name " + containerName + " already exists.")
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
    
    
    # get a container object
    container = Container(partitionName, defaultRelease)
    
    # populate the data from tredlyfile
    container.loadFromTredlyfile()
    
    # set the correct container name if it was passed to us
    container.name = containerName

    e_header("Creating Container - " + container.name + ' in partition ' + container.partitionName)
    
    # create container on the filesystem
    container.create()
    
    # start the container
    container.start(containerInterface, containerIp4, containerCidr)
    
    # get a handle to ZFS properties
    zfsContainer = ZFSDataset(container.dataset, container.mountPoint)

    # set the end build time
    container.endEpoch = int(time.time())
    zfsContainer.setProperty(ZFS_PROP_ROOT + ":endepoch", str(container.endEpoch))
    
    e_success("Creation completed at " + time.strftime('%Y-%m-%d %H:%M:%S %z', time.localtime(container.endEpoch)))
    timeTaken = container.endEpoch - container.buildEpoch
    
    # 0 seconds doesnt sound right
    if (timeTaken == 0):
        timeTaken = 1
    
    e_success("Total time taken: " + str(timeTaken) + " seconds")