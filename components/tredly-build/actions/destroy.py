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
def actionDestroyContainer(uuid, partitionName = None):
    tredlyHost = TredlyHost()
    
    ###############################
    # Start Pre flight checks
    
    # make sure the uuid exists
    if (uuid is None):
        e_error("No UUID specified.")
        exit(1)

    # if the partition name wasnt given then find it
    if (partitionName is None):
        # find the container with uuid
        partitionName = tredlyHost.getContainerPartition(uuid)

    # and the partition name
    if (partitionName is None):
        e_error("The container " + uuid + " was not found on any partition.")
        exit(1)
        
    # make sure the container exists
    if (not tredlyHost.containerExists(uuid, partitionName)):
        e_error("Could not find container with UUID " + uuid + " on partition " + partitionName)
        exit(1)

    # End pre flight checks
    ###############################

    reloadNginx = False
    
    # set up the dataset name that contains this containers data
    containerDataset = ZFS_TREDLY_PARTITIONS_DATASET + "/" + partitionName + "/" + TREDLY_CONTAINER_DIR_NAME + "/" + uuid
    
    # load the container from ZFS
    container = Container()
    
    # make it populate itself from zfs
    container.loadFromZFS(containerDataset)
    zfsContainer = ZFSDataset(container.dataset, container.mountPoint)
    startDestructEpoch = int(time.time())
    
    e_header("Destroying Container - " + container.name)
    e_note("Destruction started at " + time.strftime('%Y-%m-%d %H:%M:%S %z', time.localtime(startDestructEpoch)))

    # get some arrays
    # TODO: once the urls are populated from loadfromzfs, remove this
    redirectUrls = zfsContainer.getArray(ZFS_PROP_ROOT + ".redirect_url")
    urlCerts = zfsContainer.getArray(ZFS_PROP_ROOT + ".url_cert")
    redirectUrlCerts = zfsContainer.getArray(ZFS_PROP_ROOT + ".redirect_url_cert")

    # get a unique list of the cert names
    cleanUpCerts = list(urlCerts.values()) + list(set(redirectUrlCerts.values()) - set(urlCerts.values()))

    # check if IP exists
    try:
        e_note(container.name + " has IP address " + str(container.containerInterfaces[0].ip4Addrs[0]))
    except:
        e_warning("Container does not have an IP address")
    
    # remove container from dns
    returnCode = True
    e_note("Removing container from DNS")
    for dnsName in container.registeredDNSNames.values():
        # load the unbound file
        unboundFile = UnboundFile(UNBOUND_CONFIG_DIR + "/" + unboundFormatFilename(dnsName))

        # read contents
        unboundFile.read()

        # remove the elements for this uuid
        unboundFile.removeElementsByUUID(container.uuid)

        returnCode = (returnCode and unboundFile.write())

    # print success/failed to the user for DNS update
    if (returnCode):
        e_success("Success")
    else:
        e_error("Failed")
    
    # loop over the upstream files and delete all lines containing this ip
    for upstreamFilename in container.nginxUpstreamFiles.values():
        # load the nginx file
        upstreamFile = NginxBlock(None, None, container.nginxUpstreamDir.rstrip('/') + '/' + upstreamFilename)
        upstreamFile.loadFile()

        # remove attrs from this file
        try:
            upstreamFile.blocks['upstream'][upstreamFilename].delAttrByRegex('server', "^" + str(container.containerInterfaces[0].ip4Addrs[0].ip) + ':')
        except KeyError:
            e_error("Definition not found in" + container.nginxUpstreamDir.rstrip('/') + '/' + upstreamFilename)
        # if the upstream block is empty then delete it
        try:
            if (len(upstreamFile.blocks['upstream'][upstreamFilename].attrs) == 0):
                del upstreamFile.blocks['upstream'][upstreamFilename]
        except KeyError:
            e_error("Definition not found in" + container.nginxUpstreamDir.rstrip('/') + '/' + upstreamFilename)
        
        # save it
        upstreamFile.saveFile()
        reloadNginx = True
        
    # loop over the servername files and delete all urls related to this container
    for servernameFilename in container.nginxServernameFiles.values():
        # load the nginx file
        servernameFile = NginxBlock(None, None, container.nginxServernameDir.rstrip('/') + '/' + servernameFilename)
        servernameFile.loadFile()
        
        
        for urlObj in container.urls:
            # split up the domain and directory parts of the url
            if ('/' in urlObj['url'].rstrip('/')):
                urlDomain = urlObj['url'].split('/', 1)[0]
                urlDirectory = '/' + urlObj['url'].split('/', 1)[1]
            else:
                urlDomain = urlObj['url']
                urlDirectory = '/'

            # check if any other containers are using this url
            containersWithUrl = tredlyHost.getContainersWithArray(ZFS_PROP_ROOT + '.url', urlObj['url'])
            
            # remove our uuid from this list
            containersWithUrl.remove(container.uuid)
            
            # if no other containers are using this url then delete the location block
            if (len(containersWithUrl) == 0):
                try:
                    del servernameFile.blocks['server'][0].blocks['location'][urlDirectory]
                    
                    # check if the error docs is the last block left, and if so delete it
                    if (len(servernameFile.blocks['server'][0].blocks['location']) == 1):
                        try:
                            del servernameFile.blocks['server'][0].blocks['location']['/tredly_error_docs']
                            
                            # if there are no more locations then delete the server block
                            if (len(servernameFile.blocks['server'][0].blocks['location']) == 0):
                                del servernameFile.blocks['server'][0]
                        except:
                            print("error docs location not found")
                        
                    if (not servernameFile.saveFile()):
                        e_error("Failed to save server name file")
                    else:
                        reloadNginx = True
                except:
                    print("Location not found")
    
        # remove the redirect urls
        # TODO: These should come from container object and potentially be destroyed above
        # this requires a structure change in the container object in a future version
        
        for redirectUrl in redirectUrls.values():
            # split up the domain and directory parts of the url
            url = redirectUrl.split('://')[1]
            if ('/' in url.rstrip('/')):
                
                urlDomain = url.split('/', 1)[0]
                urlDirectory = '/' + url.split('/', 1)[1]
            else:
                urlDomain = url
                urlDirectory = '/'
                
            protocol = redirectUrl.split('://')[0]

            redirectUrlFile = nginxFormatFilename(protocol + '://' + urlDomain)

            redirectServernameFile = NginxBlock(None, None, container.nginxServernameDir.rstrip('/') + '/' + nginxFormatFilename(redirectUrlFile))
            redirectServernameFile.loadFile()

            # check if any other containers are using this redirect url
            
            containersWithUrl = tredlyHost.getContainersWithArray(ZFS_PROP_ROOT + '.redirect_url', redirectUrl)
            
            # remove our uuid from this list
            containersWithUrl.remove(container.uuid)

            # if no other containers are using this url then delete the location block
            if (len(containersWithUrl) == 0):
                try:
                    del redirectServernameFile.blocks['server'][0].blocks['location'][urlDirectory]
                except: 
                    e_error("Location block " + urlDirectory + " not found")
                
                try:
                    # check if there are now no location blocks listed
                    if (len(redirectServernameFile.blocks['server'][0].blocks['location']) == 0):
                        del redirectServernameFile.blocks['server'][0]
                except:
                    e_error("No server block found")
                
                # save it
                if (not redirectServernameFile.saveFile()):
                    e_error("Failed to save redirect file")
                else:
                    reloadNginx = True
                
    # clean up containers certs
    if (len(cleanUpCerts) > 0):
        e_note("Cleaning up SSL Certificates")
        returnCode = True
        for cert in cleanUpCerts:
            # check if this cert is in use by containers in this partition
            
            # check if any other containers are using this cert
            zfsUrlCerts = tredlyHost.getContainersWithArray(ZFS_PROP_ROOT + '.url_cert', cert)
            zfsRedirectUrlCerts = tredlyHost.getContainersWithArray(ZFS_PROP_ROOT + '.redirect_url_cert', cert)
            
            # remove our uuid from these lists
            if (container.uuid in zfsUrlCerts):
                zfsUrlCerts.remove(container.uuid)
            if (container.uuid in zfsRedirectUrlCerts):
                zfsRedirectUrlCerts.remove(container.uuid)
            
            # if nothing is using them then delete
            if (len(zfsUrlCerts) == 0) and (len(zfsRedirectUrlCerts) == 0):
                pathToCertDir = NGINX_SSL_DIR + '/' + container.partitionName + '/' + cert
                
                # make sure ther are alphanumeric chars in the path so we aren't deleting /
                if (re.search('[a-zA-Z]', pathToCertDir)):
                    # delete the directory and its contents
                    try:
                        shutil.rmtree(pathToCertDir, ignore_errors=True)
                        returnCode = (returnCode and True)
                    except IOError:
                        returnCode = (returnCode and False)
        
        if (returnCode):
            e_success("Success")
        else:
            e_error("Failed")
    
    # clean up the access file if it exists
    accessFile = container.nginxServernameDir.rstrip('/') + '/' + nginxFormatFilename(container.uuid)

    if (os.path.isfile(accessFile)):
        os.remove(accessFile)
        
        reloadNginx = True

    # remove layer 4 proxy data for this uuid
    if (len(container.layer4ProxyTcp) > 0) or (len(container.layer4ProxyUdp) > 0):
        e_note("Removing Layer 4 proxy (tcp/udp) rules for " + container.name)
        # remove any layer 4 proxy ports
        layer4Proxy = Layer4ProxyFile(IPFW_FORWARDS)
        
        # read the file
        layer4Proxy.read()
        
        # remove lines associated with this uuid
        layer4Proxy.removeElementsByUUID(container.uuid)
        
        layer4Proxy.write()
        layer4Proxy.reload()
        
        # check if postgres is installed
        cmd = ['pkg', '-j', 'trd-' + container.uuid, 'info']
        process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
        stdOut, stdErr = process.communicate()
        
        # convert output to string
        stdOutString = stdOut.decode(encoding='UTF-8')
        
        if (process.returncode != 0):
            e_error("Failed to get a list of packages for container "+ container.uuid)
        
        # loop over the lines, looking for postgres
        for line in stdOutString.splitlines():
            if (re.match('.*postgresql[0-9]*-server.*', line)):
                # found it so run the shutdown workarounds
                container.applyPostgresWorkaroundOnStop()
        
    # run through the stop process
    container.stop()

    # destroy the container
    e_note("Destroying container " + container.name)
    if (container.destroy()):
        e_success("Success")
    else:
        e_error("Failed")
    
    # update the container group members - remove this ip address
    if (container.group != '-'):
        # get a list of containergroup members
        containerGroupUUIDs = tredlyHost.getContainerGroupContainerUUIDs(container.group, container.partitionName)

        if (len(containerGroupUUIDs) > 0):
            e_note("Updating container group members for group " + container.group)
            success = True
            for memberUUID in containerGroupUUIDs:
                # load the container data from ZFS
                groupMemberDataset = ZFS_TREDLY_PARTITIONS_DATASET + "/" + partitionName + "/" + TREDLY_CONTAINER_DIR_NAME + "/" + memberUUID
                groupMember = Container()
                groupMember.loadFromZFS(groupMemberDataset)
                
                # remove the ip from this containers containergroup members
                groupMember.firewall.removeFromTable(1, str(container.containerInterfaces[0].ip4Addrs[0].ip))
                
                # apply it and get whether it succeeded or failed
                success = (success and groupMember.firewall.apply())
            if (success):
                e_success("Success")
            else:
                e_error("Failed")
    
    # reload unbound
    e_note("Reloading DNS server")
    process = Popen(['service', 'unbound', 'reload'], stdin=PIPE, stdout=PIPE, stderr=PIPE)
    stdOut, stdErr = process.communicate()
    if (process.returncode == 0):
        e_success("Success")
    else:
        e_error("Failed")
        
    # reload nginx
    if (reloadNginx):
        e_note("Reloading Layer 7 Proxy")
        process = Popen(['service', 'nginx', 'reload'], stdin=PIPE, stdout=PIPE, stderr=PIPE)
        stdOut, stdErr = process.communicate()
        if (process.returncode == 0):
            e_success("Success")
        else:
            e_error("Failed")
    
    endEpoch = time.time()
    
    e_success("Destruction completed at " + time.strftime('%Y-%m-%d %H:%M:%S %z', time.localtime(endEpoch)))
    
    uptimeEpoch = int(endEpoch) - int(container.buildEpoch)
    destructTime = int(endEpoch) - int(startDestructEpoch)
    
    uptimeMins, uptimeSecs = divmod(uptimeEpoch, 60)
    uptimeHours, uptimeMins = divmod(uptimeMins, 60)
    uptimeDays, uptimeHours = divmod(uptimeHours, 24)
    
    e_success("Container uptime: " + str(uptimeDays) + " days " + str(uptimeHours) +" hours " + str(uptimeMins) + " minutes " + str(uptimeSecs) + " seconds")
    
    e_success("Total time taken: " + str(destructTime) + " seconds")
