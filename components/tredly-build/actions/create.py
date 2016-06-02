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
def actionCreateContainer(containerName, partitionName, tredlyFilePath, ip4Addr = None):
    ######################################
    # Start Pre Flight Checks
    tredlyHost = TredlyHost()

    # make sure the Tredlyfile exists
    if (not os.path.isfile(tredlyFilePath + "/Tredlyfile")):
        e_error("Could not find Tredlyfile at " + tredlyFilePath)
        exit(1)

    # Process the tredlyfile
    builtins.tredlyFile = TredlyFile(tredlyFilePath + "/Tredlyfile")
    #builtins.tredlyFile.read()
    
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
        regex = '^(\w+)\|([\w.]+)\/(\d+)$'
        m = re.match(regex, ip4Addr)
        
        if (m is None):
            e_error('Could not validate ip4_addr "' + ip4Addr + '"' )
            exit(1)
        else:
            # assign from regex match
            interface = m.group(1)
            ip4 = m.group(2)
            cidr = m.group(3)
            
            # make sure the interface exists
            if (not networkInterfaceExists(interface)):
                e_error('Interface "' + interface + '" does not exist in "' + ip4Addr +'"')
                exit(1)
            # validate the ip4
            if (not isValidIp4(ip4)):
                e_error('IP Address "' + ip4 + '" is invalid in "' + ip4Addr +'"')
                exit(1)
            # validate the cidr
            if (not isValidCidr(cidr)):
                e_error('CIDR "' + cidr + '" is invalid in "' + ip4Addr + '"')
                exit(1)

            # make sure its not already in use
            if (ip4InUse(ip4)):
                e_error("IP Address " + ip4 + ' is already in use.')
                exit(1)

    # set up a set of certs to copy so we can validate that they exist,a nd then copy them in
    certsToCopy = set() # use a set for unique values
    for url in builtins.tredlyFile.json['container']['proxy']['layer7Proxy']:
        if (url['cert'] is not None):
            # add to the list
            certsToCopy.add(url['cert'])
        
        # add any redirect certs too
        for redirect in url['redirects']:
            if (redirect['cert'] is not None):
                certsToCopy.add(redirect['cert'])
    
    # make sure they exist
    for cert in certsToCopy:
        if (cert.startswith("partition/")):
            # set the path to the cert
            certPath = TREDLY_PARTITIONS_MOUNT + "/" + partitionName + "/" + TREDLY_PTN_DATA_DIR_NAME + cert.lstrip('partition').rstrip('/')
        elif (cert.startswith("/")):
            certPath = tredlyFilePath + cert.rstrip('/')
        else:
            e_error("Invalid certificate definition " + cert)
            exit(1)
    
        # check for server.crt and server.key
        if (not os.path.isfile(certPath + '/server.crt')):
            e_error("Missing server.crt in " + certPath + ' for cert ' + cert)
            exit(1)
        if (not os.path.isfile(certPath + '/server.key')):
            e_error("Missing server.key in " + certPath + ' for cert ' + cert)
            exit(1)

    # make sure a container with this name on this partition doesnt already exist
    if (tredlyHost.getUUIDFromContainerName(partitionName, containerName) is not None):
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
    
    e_header("Creating Container - " + container.name)
    
    # create container on the filesystem
    container.create()
    
    # Update the pkg database
    e_note("Updating package database")
    cmd = ['pkg', 'update']
    process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
    stdOut, stdErr = process.communicate()
    if (process.returncode == 0):
        # errored
        e_success("Success")
    else:
        # Success
        e_error("Failed")
        print(stdErr)
    
    e_note("Updating container's pkg catalogue")
    cmd = ['cp', '/var/db/pkg/repo-FreeBSD.sqlite', container.mountPoint + "/root/var/db/pkg"]
    process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
    stdOut, stdErr = process.communicate()
    if (process.returncode == 0):
        # errored
        e_success("Success")
    else:
        # Success
        e_error("Failed")
        print(stdErr)
    
    # start the container
    container.start(containerInterface, containerIp4, containerCidr)
    
    # get a handle to ZFS properties
    zfsContainer = ZFSDataset(container.zfsDataset, container.mountPoint)
    
    # copy in all sslcerts listed in tredlyfile to the layer 7 proxy
    # certsToCopy was set at pre flight checks
    result = True
    for cert in certsToCopy:
        e_note('Setting up SSL Cert "' + cert + '" for Layer 7 Proxy')
        dest = "/usr/local/etc/nginx/ssl/" + partitionName
        result = copyFromContainerOrPartition(cert, dest, partitionName)
    
    if (result):
        e_success("Success")
    else:
        e_error("Failed")
    
    # Register the URLs
    container.registerURLs()
    
    # set up layer 4 proxy if it was requested
    if (container.layer4Proxy):
        e_note("Configuring layer 4 Proxy (tcp/udp) for " + container.name)
        
        if (container.registerLayer4Proxy()):
            e_success("Success")
        else:
            e_error("Failed")
    
    # Update containergroup member firewall tables
    if (container.group is not None):
        e_note("Updating container group '" + container.group + "' firewall rules")
        
        # get a list of containergroup uuids
        containerGroupMembers = tredlyHost.getContainerGroupContainerUUIDs(container.group, container.partitionName)
        # and containergroup ips
        containerGroupIps = tredlyHost.getContainerGroupContainerIps(container.group, container.partitionName)

        success = True
        
        # loop over again and set the ip addresses
        for uuid in containerGroupMembers:
            firewall = IPFW('/tredly/ptn/' + container.partitionName + '/cntr/' + uuid + '/root/usr/local/etc', uuid)
            
            if (not firewall.readRules()):
                e_error("Failed to read firewall rules from " + uuid)
            
            # loop over ips, appending them to this uuid
            for ip in containerGroupIps:
                if (not firewall.appendTable(1, ip)):
                    e_error("Failed to add IP address to table 1 in " + uuid)
                
            # apply the firewall rules, keeping the return code
            success = success and firewall.apply()
            
        if (success):
            e_success("Success")
        else:
            e_error("Failed")

    # set the end build time
    container.endEpoch = int(time.time())
    zfsContainer.setProperty(ZFS_PROP_ROOT + ":endepoch", str(container.endEpoch))

    
    e_success("Creation completed at " + time.strftime('%Y-%m-%d %H:%M:%S %z', time.localtime(container.endEpoch)))
    timeTaken = container.endEpoch - container.buildEpoch
    e_success("Total time taken: " + str(timeTaken) + " seconds")