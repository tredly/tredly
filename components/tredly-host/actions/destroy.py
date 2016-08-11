# Performs actions requested by the user
import builtins
from subprocess import Popen, PIPE
import urllib.request
import os.path
import time
import argparse

from objects.tredly.tredlyhost import *
from objects.tredly.container import *
from objects.tredly.partition import *
from objects.tidycmd.tidycmd import *
from includes.util import *
from includes.defines import *
from includes.output import *


class ActionDestroy:
    def __init__(self, subject, target, identifier, actionArgs):
        tredlyHost = TredlyHost()

        # check the subject of this action
        if (subject == "partition"):
            # target == partition name

            # destroy the partition
            self.destroyPartition(target)

        elif (subject == "partitions"):
            # destroy all partitions
            self.destroyAllPartitions()

        else:
            e_error("No command " + subject + " found.")
            exit(1)

    # destroy a partition
    def destroyPartition(self, partitionName):
        # get a partition object
        partition = Partition(partitionName)
        ########### Pre flight checks

        # make sure this partition exists on disk
        if (not partition.existsInZfs()):
            e_error("Could not find partition " + partition.name)
            exit(1)

        ########### End pre flight checks

        e_header('Destroying partition "' + partition.name + '"')

        # get the number of containers in this partition - this method is much quicker than partition.getContainers
        e_note("Partition " + partition.name + " has " + str(len(partition.getContainerUUIDs())) + " Containers")
        e_note("Partition " + partition.name + " has " + str(partition.getNumFilesDirs()) + " " + "(" + partition.getDiskUsage() + ") files/folders")

        e_note("All Containers and files/folders within this partition will be destroyed.")

        # prompt the user
        confirm = input('Do you wish to destroy this partition? (y/n) ')

        if (confirm.lower() != 'y'):
            exit(1)

        # record the start time to calculate the time taken to run this command
        startTime = int(time.time())

        # get a list of containers in this partition so we can destroy them
        containers = partition.getContainers()

        # destroy the containers
        for container in containers:
            e_header("Destroying Container " + container.name)
            # stop the container if its running
            if (container.isRunning()):
                if (container.stop()):
                    e_success()
                else:
                    e_error()

            # now destroy it
            if (container.destroy()):
                e_success()
            else:
                e_error()

        success = True
        # destroy the partition itself
        success = success and partition.destroy()

        # check if the user destroyed the default partition
        if (partitionName == TREDLY_DEFAULT_PARTITION):
            # recreate the default partition
            # TODO: port partition create code to python
            createPartition = TidyCmd(['tredly', 'create', 'partition', TREDLY_DEFAULT_PARTITION])
            createPartition.run()
            success = success and (createPartition.returnCode == 0)

        # calculate time taken to run this command
        endTime = int(time.time())

        timeTaken = endTime - startTime

        # 0 seconds doesnt sound right
        if (timeTaken == 0):
            timeTaken = 1

        # only display time taken if we were destroying containers (matches bash version behaviour)
        if (len(containers) > 0):
            e_success("Total time taken: " + str(timeTaken) + " seconds")

        if (success):
            e_success()
        else:
            e_error()
            exit(1)

    def destroyAllPartitions(self):

        e_header("Destroying ALL partitions")

        tredlyHost = TredlyHost()

        # get a list of all partitions
        partitions = tredlyHost.getPartitionNames()

        e_note("The following partitions will be destroyed:")

        # show the user the partitions that will be destroyed
        for pName in partitions:
            print('  ' + pName)

        e_note("All data within these partitions will be destroyed.")

        # confirm with the user that they want to destroy the partition, containers and all
        confirm = input('Are you sure you wish to destroy these partitions? (y/n) ')

        if (confirm.lower() != 'y'):
            exit(1)

        startTime = int(time.time())

        success = True

        # destroy them
        for partitionName in partitions:
            partition = Partition(partitionName)

            e_header("Destroying Partition " + partition.name)

            # get a list of containers in this partition so we can destroy them
            containers = partition.getContainers()

            if (len(containers) == 0):
                e_note("Partition " + partition.name + " has no containers.")

            # destroy the containers
            for container in containers:
                e_header("Destroying Container " + container.name)
                # stop the container if its running
                if (container.isRunning()):
                    if (container.stop()):
                        e_success()
                    else:
                        e_error()

                # now destroy it
                if (container.destroy()):
                    e_success()

                    # show uptime
                    uptime = container.getUptime()

                    if (container.buildEpoch is not None):
                        e_success("Container uptime: " + str(uptime['days']) + " days " + str(uptime['hours']) + " hours " + str(uptime['minutes']) + " minutes " + str(uptime['seconds']) + " seconds")

                else:
                    e_error()

            # destroy the partition
            success = success and partition.destroy()

            if (success):
                e_success()
            else:
                e_error()

        # recreate the default partition
        # TODO: port partition create code to python
        createPartition = TidyCmd(['tredly', 'create', 'partition', 'default'])
        createPartition.run()

        success = success and (createPartition.returnCode == 0)

        # calculate time taken to run this command
        endTime = int(time.time())

        timeTaken = endTime - startTime

        # 0 seconds doesnt sound right
        if (timeTaken == 0):
            timeTaken = 1

        # only display time taken if we were destroying containers (matches bash version behaviour)
        if (len(containers) > 0):
            e_success("Total time taken: " + str(timeTaken) + " seconds")

        if (success):
            e_success()
        else:
            e_error()
            exit(1)
