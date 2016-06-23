#!/usr/local/bin/python3.5
from subprocess import Popen, PIPE
import os.path
import json
import sys
import re
import subprocess



scriptDirectory = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, scriptDirectory)
sys.path.insert(0, scriptDirectory + "/../components/tredly-libs/python-common")

# now that pathing is set up, import some tredly modules
from includes.output import *
from testobjects.networkchecks import *
from testobjects.firewallchecks import *

testName = "Create Container"
tredlyFilePath = "/localdev/tredly/tests/containers/wwwlayer4proxy"
containerName = "wwwtest"
partitionName="tests"


# TODO: load this from tredly-host?
layer7ProxyIP4="10.99.255.254"

# some lists for passed/failed test info
TESTS_PASSED = []
TESTS_FAILED = []

# read the tredlyfile for this script
tredlyFile = tredlyFilePath.rstrip('/') + "/tredly.json"

# Parse the tredlyfile, and exit with an error if it doesnt exist
if ( not os.path.isfile(tredlyFile)):
    e_error("No Tredlyfile found at " + tredlyFile)
    exit(1)
    
# read tredlyfile into json
with open(tredlyFile) as tredly_file:
    data = json.load(tredly_file)

exitCode = 0

e_header("Running test " + testName)

e_note("Creating Container...")

# run container replace
cmd = ['tredly', 'replace','container', partitionName, '--location=' + tredlyFilePath, '--containerName=' + containerName]
process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
stdOut, stdErr = process.communicate()
stdOutString = stdOut.decode('utf-8')
stdErrString = stdErr.decode('utf-8')
if (process.returncode != 0):
    e_error("Failed to create container")
    print(stdOutString)
    print(stdErrString)
    exit(process.returncode)

print(stdOutString)

# run tredly list containers and look for hte uuid
cmd = ['tredly', 'list','containers']
process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
stdOut, stdErr = process.communicate()
stdOutString = stdOut.decode('utf-8')
stdErrString = stdErr.decode('utf-8')
if (process.returncode != 0):
    e_error("Failed to list containers")
    print(stdOutString)
    print(stdErrString)
    exit(process.returncode)
    
# find the uuid and ip address of this container
uuid = None
containerIP4 = None

for line in stdOutString.splitlines():
    # if the line begins with partition name then look for hte container name
    if re.match(partitionName, line):
        if (line.split()[2] == containerName):
            # found it
            uuid = line.split()[3]
            containerIP4 = line.split()[4]

if (uuid is None): 
    e_error("Could not find uuid - did --containerName= work?")
    exit(1)

# set the container root
containerRoot = "/tredly/ptn/" + partitionName + "/cntr/" + uuid + "/root"

# set up some test objects
containerNetworkChecks = NetworkChecks(containerIP4)
l7proxyNetworkChecks = NetworkChecks(layer7ProxyIP4)

containerFirewallChecks = FirewallChecks(uuid)

if (len(data['container']['technicalOptions']) > 0): 
    
    # loop over all the technicaloptions and check them
    for key in data['container']['technicalOptions'].keys():
        containerValue = subprocess.getoutput("jls -j trd-" + uuid + " " + key)
        
        if (str(containerValue) == str(data['container']['technicalOptions'][key])):
            e_success("Technicaloptions: " + key + " passed")
            TESTS_PASSED.append('Technical Options: ' + key)
        else:
            e_error("FAILED: technicaloptions: " + key)
            TESTS_FAILED.append("Technical Options: " + key + " " + str(containerValue) + " should be " + str(data['container']['technicalOptions'][key]))
            exitCode=1
            

# check Resource limits
if (len(data['container']['resourceLimits']) > 0):
    # CPU
    if ("maxCpu" in data['container']['resourceLimits'].keys()):
        e_header("Checking maxCpu")
        
        # check if it was cores or a percentage
        if (str(data['container']['resourceLimits']['maxCpu']).endswith('%')):
            maxCpu = self.maxCpu.rstrip('%')
        else:   # handle cores
            # 1 core == 100% in rctl pcpu
            maxCpu = int(data['container']['resourceLimits']['maxCpu']) * 100
        
        containerCPU = subprocess.getoutput("rctl | grep '^jail:trd-" + uuid + ":pcpu' | cut -d'=' -f 2")

        if (str(containerCPU) == str(maxCpu)):
            e_success("MaxCpu Check Passed")
            TESTS_PASSED.append("RLimits: maxCpu " + containerCPU + ' == '  + str(maxCpu))
        else:
            e_error("Reported MaxCPU value " + str(containerCPU) + " does not match tredlyfile value " + str(data['container']['resourceLimits']['maxCpu']))
            _exitCode=1
            TESTS_FAILED.append('RLimits: maxCpu')

    # RAM
    if ("maxRam" in data['container']['resourceLimits'].keys()):
        e_header("Checking maxRam")
        containerRam = subprocess.getoutput("rctl | grep '^jail:trd-" + uuid + ":memoryuse' | cut -d'=' -f 2")
        
        # convert megabytes to bytes
        bytes = int(data['container']['resourceLimits']['maxRam'].rstrip('M')) * 1024 * 1024
        
        if (str(containerRam) == str(bytes)):
            e_success("MaxRam Check Passed")
            TESTS_PASSED.append("RLimits: maxRam")
        else:
            e_error("Reported MaxRam value " + str(containerRam) + " does not match tredlyfile value " + data['container']['resourceLimits']['maxRam'])
            _exitCode=1
            TESTS_FAILED.append('RLimits: maxRam')
    
    # HDD
    if ("maxHdd" in data['container']['resourceLimits'].keys()):
        e_header("Checking maxHdd")
        containerHdd = subprocess.getoutput("zfs get -H -o value quota zroot/tredly/ptn/" + partitionName + "/cntr/" + uuid)
        
        # convert value received from zfs to megabytes
        megabytes = int(containerHdd.rstrip('G')) * 1024
        
        if (str(megabytes) == str(data['container']['resourceLimits']['maxHdd'].rstrip('M'))):
            e_success("MaxHdd Check Passed")
            TESTS_PASSED.append("RLimits: maxHdd")
        else:
            e_error("Reported MaxHdd value " + str(containerHdd) + " does not match tredlyfile value " + data['container']['resourceLimits']['maxHdd'])
            _exitCode=1
            TESTS_FAILED.append('RLimits: maxHdd')

e_header("Checking URLs")

# check http and https access
httpPorts = []
for url in data['container']['proxy']['layer7Proxy']:
    # strip out the host so we can fake it
    urlHost = url['url'].split('://',1)[-1]
    urlHost = urlHost.split('/', 1)[0]
    
    if (url['cert'] is None):
        proto = 'http'
        port = '80'
    else:
        proto = 'https'
        port = "443"
    
    # append the port
    httpPorts.append(port)
    
    # grab the url directory
    if ('/' in url['url'].split('://', 1)[-1]):
        urlDirectory = url['url'].split('://', 1)[-1].split('/', 1)[-1]
    else:
        urlDirectory = '/'
    
    urlString = proto + '://' + urlHost + ':' + port + urlDirectory 

    # check max file size against the layer 7 proxy
    if (url['maxFileSize'] is not None):
        maxFileSize = url['maxFileSize'].rstrip('m')
        if (l7proxyNetworkChecks.checkUrlMaxFileSize(urlString, maxFileSize)):
            TESTS_PASSED.append("MaxFileSize: passed")
        else:
            TESTS_FAILED.append("MaxFileSize: failed")

    # check direct connection to container
    if (containerNetworkChecks.checkURL(urlString,url['enableWebsocket'])):
        TESTS_PASSED.append("Connection from L7Proxy " + urlString)
    else:
        TESTS_FAILED.append("Connection from L7Proxy " + urlString)
        
    # set up the url
    urlString = 'https://' + urlHost + ':443' + urlDirectory 

    # check the HTTPS connectivity from the hosts private interface to the layer 7 proxy
    if (l7proxyNetworkChecks.checkURL(urlString, url['enableWebsocket'], ['200', '301'])):
        TESTS_PASSED.append("Connection to L7Proxy " + urlString)
    else:
        TESTS_FAILED.append("Connection to L7Proxy " + urlString)
    
    # set up the url
    urlString = 'http://' + urlHost + ':80' + urlDirectory 

    # check the HTTP connectivity from the hosts private interface to the layer 7 proxy
    if (l7proxyNetworkChecks.checkURL(urlString, url['enableWebsocket'], ['200', '301'])):
        TESTS_PASSED.append("Connection to L7Proxy " + urlString)
    else:
        TESTS_FAILED.append("Connection to L7Proxy " + urlString)
    
    # check redirects
    for redirect in url['redirects']:
        # check the HTTP connectivity from the hosts private interface to the layer 7 proxy
        if (l7proxyNetworkChecks.checkURL(redirect['url'], False, ['301'])):
            TESTS_PASSED.append("URL Redirect " + redirect['url'])
        else:
            TESTS_FAILED.append("URL Redirect " + redirect['url'])

# check the ports from nmap
for port in set(httpPorts):
    e_header("checking http(s) port " + port)
    if (containerNetworkChecks.checkPort('tcp', port)):
        TESTS_PASSED.append("HTTP(s) port " + port + " is open")
    else:
        TESTS_FAILED.append("HTTP(s) port " + port + " is not open")


####
layer4Tcp = []
layer4Udp = []
# check layer 4 proxy
if (data['container']['proxy']['layer4Proxy']):
    e_header("Checking layer 4 proxy")
    # check /usr/local/etc/ipfw.layer4
    with open('/usr/local/etc/ipfw.layer4') as layer4file:
        for line in layer4file.readlines():
            if (line.startswith('redirect_port')):

                # add to an array
                if (line.split()[1] == 'tcp'):
                    layer4Tcp = line.split()[2]
                    
                elif (line.split()[1] == 'udp'):
                    layer4Udp = line.split()[2]

# check tcp ports
for tcpinport in data['container']['firewall']['allowPorts']['tcp']['in']:
    # connect directly to the container's port
    if (containerNetworkChecks.checkPort('tcp', tcpinport)):
        TESTS_PASSED.append("TCPINPORT: " + str(tcpinport) + ' is open')
    else:
        TESTS_FAILED.append("TCPINPORT: " + str(tcpinport) + ' is closed')
    
    # check layer 4 proxy file
    if (containerIP4 + ':' + str(tcpinport) in layer4Tcp):
        TESTS_PASSED.append("Layer4Proxy: " + containerIP4 + ':' + str(tcpinport) + 'tcp found in /usr/local/etc/ipfw.layer4')
    else:
        TESTS_FAILED.append("Layer4Proxy: " + containerIP4 + ':' + str(tcpinport) + 'tcp not in /usr/local/etc/ipfw.layer4')

for udpinport in data['container']['firewall']['allowPorts']['udp']['in']:
    # connect directly to the container's port
    if (containerNetworkChecks.checkPort('udp', udpinport)):
        TESTS_PASSED.append("UDPINPORT: " + str(udpinport) + ' is open')
    else:
        TESTS_FAILED.append("UDPINPORT: " + str(udpinport) + ' is closed')
    
    if (containerIP4 + ':' + str(udpinport) in layer4Udp):
        TESTS_PASSED.append("Layer4Proxy: " + containerIP4 + ':' + str(udpinport) + 'udp found in /usr/local/etc/ipfw.layer4')
    else:
        TESTS_FAILED.append("Layer4Proxy: " + containerIP4 + ':' + str(udpinport) + 'udp not in /usr/local/etc/ipfw.layer4')

# check ipv4 whitelist was applied to the container
if (len(data['container']['firewall']['ipv4Whitelist']) > 0):
    
    e_header("Checking IPv4 Whitelist in container")
    
    nginxAccessFile = '/usr/local/etc/nginx/access/' + uuid
    
    for ip4 in data['container']['firewall']['ipv4Whitelist']:
        # check that the allow rule exists in nginx access file for this container
        foundInAccessFile = subprocess.getoutput("cat " + nginxAccessFile + ' | grep "^allow ' + ip4 + ';$" | wc -l | tr -d "[[:space:]]"')

        if (int(foundInAccessFile) == 1):
            TESTS_PASSED.append("IPv4WHITELIST Layer 7: " + ip4 + ' is whitelisted')
        else:
            TESTS_FAILED.append("IPv4WHITELIST Layer 7 : " + ip4 + ' is not whitelisted')
            
        # check if the ip doesnt container a range and if not add /32 to it
        if ('/' not in ip4):
            ip4WithCidr = ip4 + '/32'
        else:
            ip4WithCidr = ip4
        
        if (containerFirewallChecks.checkIpfwTable(3, ip4WithCidr)):
            TESTS_PASSED.append("IPv4WHITELIST: " + ip4WithCidr + ' is whitelisted')
        else:
            TESTS_FAILED.append("IPv4WHITELIST: " + ip4WithCidr + ' is not whitelisted')
            
            
        
    # ensure this whitelist is applied to the layer 7 proxy
    
    

# check persistent storage
if ("persistentStorage" in data['container']):
    e_header("Checking Persistent Storage")
    
    persistentDataset="zroot/tredly/ptn/" + partitionName + "/psnt/" + data['container']['persistentStorage']['identifier']
    
    zfsFound = subprocess.getoutput("zfs list -H " + persistentDataset + " | wc -l  | tr -d '[[:space:]]'")
    
    if (int(zfsFound) == 1):
        TESTS_PASSED.append('Persistent Storage: ZFS Dataset created')
    else:
        TESTS_FAILED.append('Persistent Storage: ZFS Dataset not found')
    
    # make sure its mounted to the container
    mountLine = subprocess.getoutput("mount | grep '^" + persistentDataset + "'")
    
    # ensure that its mounted in the right spot
    if (mountLine.split()[2].endswith(data['container']['persistentStorage']['mountPoint'])):
        TESTS_PASSED.append('Persistent Storage: ZFS Dataset mounted')
    else:
        TESTS_FAILED.append('Persistent Storage: ZFS Dataset not mounted')
    
if (len(data['container']['customDNS']) > 0):
    if (not os.path.isfile(containerRoot + '/etc/resolv.conf')):
        TESTS_FAILED.append('resolv.conf: file does not exist')
    else:
        for value in data['container']['customDNS']:
            valueFound = subprocess.getoutput("cat " + containerRoot + "/etc/resolv.conf | grep -E " + value + " | wc -l | tr -d '[[:space:]]'")
            
            if (int(valueFound) == 0):
                TESTS_FAILED.append("resolv.conf: " + value + " missing from file")
                exitCode=1
            elif (int(valueFound) == 1):
                TESTS_PASSED.append("resolv.conf: " + value + " found once")
            else:
                TESTS_FAILED.append("resolv.conf: " + value + " found " + valueFound + " times")
                exitCode=1

e_note("Destroying Container")
# run container destroy
cmd = ['tredly', 'destroy','container', uuid]
process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
stdOut, stdErr = process.communicate()
stdOutString = stdOut.decode('utf-8')
stdErrString = stdErr.decode('utf-8')
if (process.returncode != 0):
    e_error("Failed to destroy container")
    print(stdOutString)
    print(stdErrString)
    exit(process.returncode)

print(stdOutString)

#####################
# POST DESTROY CHECKS
#####################

# check that nginx has been cleaned up
e_header("Checking if files have been removed")

dirs = {}
dirs['nginx_access'] = "/usr/local/etc/nginx/access"
dirs['nginx_server_name'] = "/usr/local/etc/nginx/server_name"
dirs['nginx_upstream'] = "/usr/local/etc/nginx/upstream"
dirs['unbound'] = "/usr/local/etc/unbound/configs"
dirs['nginx_ssl'] = "/usr/local/etc/nginx/ssl"

for key, dir in dirs.items():
    e_note("Checking " + dir)
    numFiles = subprocess.getoutput("ls -1 " + dir + " | wc -l")
    
    if (int(numFiles) == 0):
        TESTS_PASSED.append('Filesystem: ' + dir)
    else:
        TESTS_FAILED.append('Filesystem: remaining files in ' + dir)
        exitCode = 1

e_success("Done")


e_header("Test Results")
print("\033[32mPASSED TESTS:")
print("-------------")

for item in TESTS_PASSED:
    print (item)

print("")
print("\033[31mFAILED TESTS:")
print("-------------")

for item in TESTS_FAILED:
    print (item)

print("\033[0m\033[39m")
exit(exitCode)
