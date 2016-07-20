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
        elif (subject == "containers"):
            # target can be a partition name or None (all containers on host)
            self.stopContainers(target)
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



    # stop a container
    def stopContainers(self, partitionName):
        startTime = time.time()
        tredlyHost = TredlyHost()

        ###############################
        # Start Pre flight checks


        # End pre flight checks
        ###############################

        containers = []

        # if partitionName was set then get that partitions containers
        if (partitionName is not None):
            # get a list of containers on this partition
            containers = tredlyHost.getPartitionContainerUUIDs(partitionName)
        else:
            # get a list of all containers on host
            containers = tredlyHost.getAllContainerUUIDs()

        # form a list of running containers
        runningContainers = []
        for uuid in containers:
            # check if its running
            if (tredlyHost.containerIsRunning(uuid)):
                # append it to the running containers list
                runningContainers.append(uuid);

        if (len(runningContainers) == 0):
            e_note("No containers to stop.")
            exit(0)

        # prompt the user since there are many containers to stop
        e_note("The following containers will be stopped:")
        for uuid in runningContainers:
            print("  " + tredlyHost.getContainerNameFromUUID(uuid, partitionName))

        userInput = input("Are you sure you wish to stop these containers? (y/n) ")

        # if the user said yes then stop all containers
        if (userInput.lower() == 'y'):
            # loop over and stop the containers
            for uuid in runningContainers:

                # load the container from ZFS
                container = Container()

                # if partitionName was none then find this containers partitionName
                if (partitionName is None):
                    containerPartitionName = tredlyHost.getContainerPartition(uuid)
                else:
                    containerPartitionName = partitionName

                # set up the dataset name that contains this containers data
                containerDataset = ZFS_TREDLY_PARTITIONS_DATASET + "/" + containerPartitionName + "/" + TREDLY_CONTAINER_DIR_NAME + "/" + uuid

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

            # show the user how long this took
            endTime = time.time()

            e_success("Stop containers completed at " + time.strftime('%Y-%m-%d %H:%M:%S %z', time.localtime(endTime)))

            timeTaken = int(endTime) - int(startTime)

            # 0 seconds doesnt sound right
            if (timeTaken == 0):
                timeTaken = 1

            e_success("Total time taken: " + str(timeTaken) + " seconds")
