# A class to retrieve data from a tredly host
from subprocess import Popen, PIPE
from includes.util import *
from includes.defines import *
from includes.output import *
import re

class TredlyHost:
    
    # Constructor
    #def __init__(self):
    
    # returns a list of partition names
    def getPartitionNames(self):
        # create a list to pass back
        partitionNames = []
        

        # get a list of the properties for these group members
        cmd = ['zfs', 'list', '-H', '-o' 'name', '-r', '-d', '1', ZFS_TREDLY_PARTITIONS_DATASET]
        process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
        stdOut, stdErr = process.communicate()
        if (process.returncode != 0):
            e_error("Failed to get list of partition names")
            
        # convert stdout to string
        stdOut = stdOut.decode(encoding='UTF-8').rstrip();
        
        for line in stdOut.splitlines():
            # strip off the dataset part
            line = line.replace(ZFS_TREDLY_PARTITIONS_DATASET, '').strip()
            
            # check if the line still contains data
            if (len(line) > 0):
                # and now strip the slash which should be at the beginning
                line = line.lstrip('/')
                
                partitionNames.append(line)
            
        return partitionNames
    
    # returns an array of ip addresses of all containers in the given group/partition
    def getContainerGroupContainerIps(self, containerGroup, partitionName):
        # form the base dataset to search in
        dataset = ZFS_TREDLY_PARTITIONS_DATASET + "/" + partitionName + '/cntr'
        
        # and the property
        datasetProperty = ZFS_PROP_ROOT +':ip4_addr'
        
        # get a list of uuids in this group
        groupMemberUUIDs = self.getContainerGroupContainerUUIDs(containerGroup, partitionName)
        
        # create a list to pass back
        ipList = []
        
        # loop over htem and get the data
        for uuid in groupMemberUUIDs:
            # get a list of the properties for these group members
            cmd = ['zfs', 'get', '-H', '-r', '-o' 'name,value', datasetProperty, dataset + '/' + uuid]
            process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
            stdOut, stdErr = process.communicate()
            if (process.returncode != 0):
                e_error("Failed to get list of containergroup ips")
            
            # convert stdout to string
            stdOut = stdOut.decode(encoding='UTF-8').rstrip();
            
            # extract the data if it exists
            if (re.match("^" + dataset + '/' + uuid, stdOut)):
                # extract the value part
                ip4Part = stdOut.split()[1]
                
                # extract the ip
                regex = '^(\w+)\|([\w.]+)\/(\d+)$'
                m = re.match(regex, ip4Part)
                
                if (m is not None):
                    ipList.append(m.group(2))
        
        return ipList
    
    # get a list of containers within a container group and partition
    def getContainerGroupContainerUUIDs(self, containerGroup, partitionName):
        # form the base dataset to search in
        dataset = ZFS_TREDLY_PARTITIONS_DATASET + "/" + partitionName
        
        # and the property
        datasetProperty = ZFS_PROP_ROOT +':containergroupname'
        
        # get a list of the properties
        cmd = ['zfs', 'get', '-H', '-r', '-o' 'name,value', datasetProperty, dataset]
        process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
        stdOut, stdErr = process.communicate()
        if (process.returncode != 0):
            e_error("Failed to get list of containergroup members")
        
        # convert stdout to string
        stdOut = stdOut.decode(encoding='UTF-8').rstrip();
        
        # create a list to pass back
        containerList = []
        
        # loop over the results looking for our value
        for line in iter(stdOut.splitlines()):
            # check if it matches our containergroup
            if (re.match("^.*\s" + containerGroup + "$", line)):
                # extract the dataset part
                datasetPart = line.split()[0]
                
                # get the uuid and append to our list
                containerList.append(datasetPart.split('/')[-1])
        
        return containerList
    
    # get a list of containers within a container group and partition
    def getPartitionContainerUUIDs(self, partitionName):
        # form the base dataset to search in
        dataset = ZFS_TREDLY_PARTITIONS_DATASET + "/" + partitionName + "/" + TREDLY_CONTAINER_DIR_NAME
        
        # get a list of the containers
        cmd = ['zfs', 'list', '-H', '-r', '-o' 'name', dataset]
        process = Popen(cmd, stdin=PIPE, stdout=PIPE, stderr=PIPE)
        stdOut, stdErr = process.communicate()
        if (process.returncode != 0):
            e_error("Failed to get list of partition members")
        
        # convert stdout to string
        stdOut = stdOut.decode(encoding='UTF-8').rstrip()
        
        # create a list to pass back
        containerList = []
        
        # loop over the results looking for our value
        for line in iter(stdOut.splitlines()):
            # check if it matches our containergroup
            if (re.match("^" + dataset + "/.*$", line)):
                # get the uuid and append to our list
                containerList.append(line.split('/')[-1])
        
        return containerList
    
    # check if a container exists
    def containerExists(self, uuid, partitionName = None):
        if (uuid is None):
            return False
        if (len(uuid) == 0):
            return False
        
        # find hte partition name if partition name was empty
        if (partitionName is None):
            # get the partition name
            partitionName = self.getContainerPartition(uuid)
            
            # if None was returned then the container doesnt exist
            if (partitionName is None):
                return False
        
        # get a list of containers in this partition
        containerUUIDs = self.getPartitionContainerUUIDs(partitionName)

        # check if it exists in the array
        if (uuid in containerUUIDs):
            return True

        return False
    
    # finds the partition that the given uuid resides on
    def getContainerPartition(self, uuid):
        zfsCmd = ['zfs', 'list', '-d6', '-rH', '-o', 'name', ZFS_TREDLY_PARTITIONS_DATASET]
        zfsResult = Popen(zfsCmd, stdout=PIPE)
        stdOut, stdErr = zfsResult.communicate()
        
        # convert stdout to string
        stdOutString = stdOut.decode("utf-8").strip()
        
        # loop over the results looking for our uuid
        for line in stdOutString.splitlines():
            line.strip()
            if (line.endswith(TREDLY_CONTAINER_DIR_NAME + "/" + uuid)):
                # found it so extract the partition name
                partitionName = line.replace(ZFS_TREDLY_PARTITIONS_DATASET + '/', '')
                
                partitionName = partitionName.replace('/' + TREDLY_CONTAINER_DIR_NAME + '/' + uuid, '')
                
                return partitionName
        
        # return none if nothing found
        return None
    
    # searches for all containers that have a given array
    def getContainersWithArray(self, datasetProperty, url):
        # form the base dataset to search in
        dataset = ZFS_TREDLY_PARTITIONS_DATASET
        
        cmd =  ['zfs', 'get', '-H', '-r', '-o' 'name,value,property', 'all', dataset]
        result = Popen(cmd, stdout=PIPE)
        stdOut, stdErr = result.communicate()
        
        # convert stdout to string
        stdOutString = stdOut.decode("utf-8").strip()
        uuids = []
        
        # loop over the results looking for our dataset
        for line in stdOutString.splitlines():
            line.strip()

            if (re.search(datasetProperty + ':\d+$', line)):
                # split it up into elements
                lineElements = line.split()

                # match 2nd element to the url
                # and the 3rd element to the dataset proeprty name
                if (lineElements[1] == url) and (re.match(datasetProperty + ':\d+$', lineElements[2])):
                    # found it so extract the uuid from the first element and append to our array
                    uuids.append(lineElements[0].split('/')[-1])
        
        # return a set as we are only after unique values
        return set(uuids)
    
    # finds the uuid of a container with containername
    def getUUIDFromContainerName(self, partitionName, containerName):
        # form the base dataset to search in
        dataset = ZFS_TREDLY_PARTITIONS_DATASET + "/" + partitionName + "/" + TREDLY_CONTAINER_DIR_NAME
        
        # get a list of the containers
        zfsCmd = ['zfs', 'get', '-H', '-r', '-o', 'name,property,value', 'all', dataset]
        grepCmd = ['grep', '-F', ZFS_PROP_ROOT + ':containername']

        zfsProcess = Popen(zfsCmd, stdin=PIPE, stdout=PIPE, stderr=PIPE)
        grepProcess = Popen(grepCmd, stdin=zfsProcess.stdout, stdout=PIPE, stderr=PIPE)

        stdOut, stdErr = grepProcess.communicate()
        
        if (grepProcess.returncode != 0):
            return None

        # convert stdout to string
        stdOut = stdOut.decode(encoding='UTF-8').rstrip()

        # loop over the results looking for our value
        for line in iter(stdOut.splitlines()):
            # split up the line
            splitLine = line.split()

            # check if it matches our containergroup
            if (splitLine[2] == containerName):
                # get the uuid and append to our list
                return splitLine[0].split('/')[-1]
