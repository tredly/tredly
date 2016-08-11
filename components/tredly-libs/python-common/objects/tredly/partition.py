# A class to represent a tredly partition
import os
import shutil

from objects.tidycmd.tidycmd import *
from includes.util import *
from includes.defines import *
from includes.output import *
from objects.tredly.container import *


class Partition:
    # Constructor
    def __init__(self, name, maxHdd = None, maxCpu = None, maxRam = None):
        self.name = name;
        self.maxHdd = maxHdd;
        self.maxCpu = maxCpu;
        self.maxRam = maxRam;
        # lists
        self.publicIPs = [];    # list of public ips assigned to this partition
        self.ip4Whitelist = []; # list of ip addresses whitelisted for this partition

    # Action: check to see if this partition exists in ZFS
    #
    # Pre: this object exists
    # Post:
    #
    # Params:
    #
    # Return: True if exists, False otherwise
    def existsInZfs(self):
        partitionLocation = ZFS_TREDLY_PARTITIONS_DATASET + '/' + self.name

        # check that the zfs dataset for this partition actually exists
        zfsList = TidyCmd(["zfs", "list", partitionLocation])
        zfsList.run()

        return (zfsList.returnCode == 0)

    # Action: destroy this partition on the host
    #
    # Pre: this object exists
    # Post: the partition on the file system has been deleted
    #
    # Params:
    #
    # Return: True if succeeded, False otherwise
    def destroy(self):
        # make sure our name isnt none (so we dont destroy the entire partitions dataset)
        # and has a length
        if ((self.name != None) and (len(self.name) > 0)):
            # destroy  containers within this partition
            zfsDestroy = TidyCmd(["zfs", "destroy", "-rf", ZFS_TREDLY_PARTITIONS_DATASET + '/' + self.name])
            zfsDestroy.run()

            # clean up the directory if its left behind and destroy succeeded
            if (zfsDestroy.returnCode == 0):
                mountPoint = TREDLY_PARTITIONS_MOUNT + '/' + self.name

                # ensure the mountpoint is a directory
                if (os.path.isdir(mountPoint)):
                    try:
                        shutil.rmtree(mountPoint)
                    except:
                        return False

            return True
        else:
            return False

        # catch all errors
        return False

    # Action: get a list of all containers within this partition
    #
    # Pre: this object exists
    # Post: any containers within this partition have been returned
    #
    # Params: alphaOrder - boolean, if true sort in alphabetical order
    #
    # Return: list of Container objects
    def getContainers(self, alphaOrder = True):
        # get a list of containers within this partition
        zfsCmd = TidyCmd(["zfs", "list", "-d3", "-rH", "-o", "name", ZFS_TREDLY_PARTITIONS_DATASET + '/' + self.name + '/' + TREDLY_CONTAINER_DIR_NAME])
        zfsCmd.appendPipe(["grep", "-Ev", TREDLY_CONTAINER_DIR_NAME + '$|*./root'])

        if (alphaOrder):
            zfsCmd.appendPipe(["sort", "-t", "^", "-k", "2"])

        containerStdOut = zfsCmd.run()

        # list to return
        containers = []

        for container in containerStdOut.splitlines():
            # extract uuid from dataset
            uuid = container.split('/')[-1]

            # create new container object
            container = Container()

            # set up the dataset name that contains this containers data
            containerDataset = ZFS_TREDLY_PARTITIONS_DATASET + "/" + self.name + "/" + TREDLY_CONTAINER_DIR_NAME + "/" + uuid

            # load the containers properties from ZFS
            container.loadFromZFS(containerDataset)

            # append to our list
            containers.append(container)

        return containers

    # Action: get the amount of disk space used by this partition
    #
    # Pre: this object exists
    # Post: the disk usage of this partition has been returned
    #
    # Params:
    #
    # Return: string of disk size
    def getDiskUsage(self):
        zfs = ZFSDataset(ZFS_TREDLY_PARTITIONS_DATASET + "/" + self.name)

        return zfs.getProperty('used')


    # Action: get the number of containers in this partition
    #         this is a much quicker method than getContainers()
    #
    # Pre: this object exists
    # Post:
    #
    # Params:
    #
    # Return: int
    def getContainerUUIDs(self):
        # get a list of containers within this partition
        zfsCmd = TidyCmd(["zfs", "list", "-d3", "-rH", "-o", "name", ZFS_TREDLY_PARTITIONS_DATASET + '/' + self.name + '/' + TREDLY_CONTAINER_DIR_NAME])
        zfsCmd.appendPipe(["grep", "-Ev", TREDLY_CONTAINER_DIR_NAME + '$|*./root'])

        stdOut = zfsCmd.run()

        uuids = []

        for line in stdOut.splitlines():
            uuids.append(line.split('/')[-1])

        return uuids

    # Action: get the number of files/directories in this partition
    #
    # Pre: this object exists
    # Post: the number of files/directories
    #
    # Params:
    #
    # Return: int
    def getNumFilesDirs(self, exclude = ['cntr']):
        count = 0
        # count the tree
        i = 0
        # loop over the directory structure and count the dirs/files, excluding '/cntr' from the root dir
        for root, dirs, files in os.walk(TREDLY_PARTITIONS_MOUNT + '/' + self.name, topdown=True):
            # if this is the root dir then exclude, otherwise accept all
            if (i == 0):
                dirs[:] = [d for d in dirs if d not in exclude]

            # increment counter
            count += len(dirs) + len(files)

        return count
