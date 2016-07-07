# Performs actions requested by the user
import builtins
from subprocess import Popen, PIPE
import urllib.request
import os.path
import time
import argparse

from objects.tredly.tredlyhost import *
from objects.tredly.container import *
from includes.util import *
from includes.defines import *
from includes.output import *


# config the host
class ActionMove:
    def __init__(self, subject, target, identifier, actionArgs):
        tredlyHost = TredlyHost()
        
        # check the subject of this action
        if (subject == "container"):
            # target == container uuid
            # identifier == host to move to
            
            # move the container to the new host
            self.moveContainer(target, identifier)

        else:
            e_error("No command " + subject + " found.")
            exit(1)
    
    # move a container to a new host
    def moveContainer(self, containerUuid, host):
        
        tredlyHost = TredlyHost()
        # Checks:
        if (containerUuid is None):
            e_error("Please include a UUID to move.")
            exit(1)
            
        if (host is None):
            e_error("Please include a host to move to")
            exit(1)
        
        # make sure the container exists
        if (not tredlyHost.containerExists(containerUuid)):
            e_error("Container " + containerUuid + " does not exist")
            exit(1)
        
        # TODO: make sure the destination host partition exists

        # get the partition name
        partitionName = tredlyHost.getContainerPartition(containerUuid)
        
        # set up the dataset
        localDataset = ZFS_TREDLY_PARTITIONS_DATASET + '/' + partitionName + '/' + TREDLY_CONTAINER_DIR_NAME + '/' + containerUuid
        
        container = Container()
        container.loadFromZFS(localDataset)
        
        e_header("Moving container " + containerUuid + " to host " + host)
        
        # move the container, and exit 1 if it fails
        if (not container.moveToHost(host)):
            exit(1)