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

class ActionReplace:
    def __init__(self, subject, target, identifier, actionArgs):
        tredlyHost = TredlyHost()
        # check if a partition/target was specified
        if (target is not None):
            actionArgs['partitionName'] = target
            
            # make sure this partition exists
            partitions = tredlyHost.getPartitionNames()
            
            # make sure it exists
            if (actionArgs['partitionName'] not in partitions):
                e_error('Partition "' + actionArgs['partitionName'] + '" does not exist.')
                exit(1)

        if (subject == "container"):
            self.replaceContainer(actionArgs['containerName'], identifier, target, actionArgs['path'], actionArgs['ip4Addr'])
            
    # replace a container
    def replaceContainer(self, containerName, uuidToReplace, partitionName, tredlyFilePath, ip4Addr = None):
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
        
        
        # process the tredlyfile
        builtins.tredlyFile = TredlyFile(tredlyFilePath + "/Tredlyfile")
    
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
            
        startReplaceEpoch = int(time.time())
        e_note("Replace started at " + time.strftime('%Y-%m-%d %H:%M:%S %z', time.localtime(startReplaceEpoch)))
        
        zfsTredly = ZFSDataset(ZFS_TREDLY_DATASET)
        defaultRelease = zfsTredly.getProperty(ZFS_PROP_ROOT + ':default_release_name')
        # create the container
        # get a container object
        newContainer = Container(partitionName, defaultRelease)
        
        # populate the data from tredlyfile
        newContainer.loadFromTredlyfile()
        
        # set the correct container name if it was passed to us
        if (containerName is not None):
            newContainer.name = containerName
    
        e_header("Creating Container - " + newContainer.name + ' in partition ' + newContainer.partitionName)
        
        # create container on the filesystem
        if (not newContainer.create()):
            # container create failed so rename the old container back
            e_error("Failed to create new container")
            # set the name back 
            zfsOldContainer.setProperty(ZFS_PROP_ROOT + ':containername', oldContainerName)
        
        # start the container
        newContainer.start(containerInterface, containerIp4, containerCidr)
        
        # destroy the old container if it exists on this partition
        if (tredlyHost.containerExists(oldContainerUUID, partitionName)):
            # load the container from ZFS
            oldContainer = Container()
            
            # set up the dataset name that contains this containers data
            oldContainerDataset = ZFS_TREDLY_PARTITIONS_DATASET + "/" + partitionName + "/" + TREDLY_CONTAINER_DIR_NAME + "/" + oldContainerUUID
            
            # make the container populate itself from zfs
            oldContainer.loadFromZFS(oldContainerDataset)
            # make sure the uuid is populated
            if (oldContainer.uuid is None):
                oldContainer.uuid = uuid
            
            startDestructEpoch = int(time.time())
            e_header("Destroying Container - " + oldContainer.name)
            
            # run through the stop process
            oldContainer.stop()
    
            # destroy the container
            e_note("Destroying container " + str(oldContainer.name))
            if (oldContainer.destroy()):
                e_success("Success")
            else:
                e_error("Failed")
            
        endReplaceEpoch = int(time.time())
        e_success("Replace completed at " + time.strftime('%Y-%m-%d %H:%M:%S %z', time.localtime(endReplaceEpoch)))
        timeTaken = endReplaceEpoch - startReplaceEpoch
        e_success("Total time taken: " + str(timeTaken) + " seconds")
        
        return True