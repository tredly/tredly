#!/usr/local/bin/python3.5
from subprocess import Popen, PIPE
import os.path
import json
import sys
import re
import subprocess
import ipaddress

scriptDirectory = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, scriptDirectory)
sys.path.insert(0, scriptDirectory + "/../components/tredly-libs/python-common")

# now that pathing is set up, import some tredly modules
from includes.output import *
from includes.util import *
from testobjects.configchecks import *
#from testobjects.firewallchecks import *

testName = "Create/Modify/Delete Partition"
partitionName="test-partition"

# some lists for passed/failed test info
TESTS_PASSED = []
TESTS_FAILED = []

configChecks = ConfigChecks()
staticIPsChecks = ConfigChecks('/usr/local/etc/tredly/static-ips.conf')
sshChecks = ConfigChecks('/etc/ssh/sshd_config', ' ')
unboundChecks = ConfigChecks('/usr/local/etc/unbound/unbound.conf', ': ')
rcConfChecks = ConfigChecks('/etc/rc.conf', '=')

containerNetworkInterface = 'bridge1'
containerNetworkIP = '10.0.0.0'
containerNetworkCIDR = '16'
containerNetwork = ipaddress.IPv4Interface(containerNetworkIP + '/' + containerNetworkCIDR)
containerNetworkNetmask = str(containerNetwork.with_netmask).split('/', 1)[-1]

e_header("Running container subnet change test")
# modify the container subnet
cmd = ['tredly', 'config', 'container', 'subnet', str(containerNetwork.network)]
process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
stdOut, stdErr = process.communicate()
stdOutString = stdOut.decode("utf-8", "replace")
stdErrString = stdErr.decode('utf-8', 'replace')
print(stdOutString)

# get the interface for the bridge
bridgeIP = getInterfaceIP4(containerNetworkInterface)
hostPrivateIP = str(containerNetwork.network.broadcast_address - 1).strip()

# check that lifnetwork has been updated
if (configChecks.checkOption('lifNetwork', str(containerNetwork.network))):
    TESTS_PASSED.append("Modify container subnet: tredly-host.conf lifNetwork")
else:
    print(stdErrString)
    TESTS_FAILED.append("Modify container subnet: tredly-host.conf lifNetwork")
    

if (configChecks.checkOption('dns', hostPrivateIP)):
    TESTS_PASSED.append("Modify container subnet: tredly-host.conf dns")
else:
    print(stdErrString)
    TESTS_FAILED.append("Modify container subnet: tredly-host.conf dns")
    
    
if (configChecks.checkOption('httpproxy', hostPrivateIP)):
    TESTS_PASSED.append("Modify container subnet: tredly-host.conf httpproxy")
else:
    print(stdErrString)
    TESTS_FAILED.append("Modify container subnet: tredly-host.conf httpproxy")

if (configChecks.checkOption('vnetdefaultroute', hostPrivateIP)):
    TESTS_PASSED.append("Modify container subnet: tredly-host.conf vnetdefaultroute")
else:
    print(stdErrString)
    TESTS_FAILED.append("Modify container subnet: tredly-host.conf vnetdefaultroute")

if (bridgeIP == hostPrivateIP):
    TESTS_PASSED.append("Modify container subnet: bridge ip matches host private ip")
else:
    print(stdErrString)
    TESTS_FAILED.append("Modify container subnet: bridge ip does not match host private ip")

if (rcConfChecks.checkOption('ifconfig_' + containerNetworkInterface, '"inet ' + hostPrivateIP + ' netmask ' + containerNetworkNetmask + '"')):
    TESTS_PASSED.append("Modify container subnet: rc.conf ifconfig")
else:
    print(stdErrString)
    TESTS_FAILED.append("Modify container subnet: rc.conf ifconfig")

if (unboundChecks.checkOption('interface', hostPrivateIP)):
    TESTS_PASSED.append("Modify container subnet: unbound.conf interface")
else:
    print(stdErrString)
    TESTS_FAILED.append("Modify container subnet: unbound.conf interface")
    
if (staticIPsChecks.checkOption('tredlyLayer7Proxy', str(containerNetwork.network.broadcast_address - 2) + '/' + containerNetworkCIDR)):
    TESTS_PASSED.append("Modify container subnet: static-ips.conf tredlyLayer7Proxy")
else:
    print(stdErrString)
    TESTS_FAILED.append("Modify container subnet: static-ips.conf tredlyLayer7Proxy")

if (staticIPsChecks.checkOption('tredlyDNS', str(containerNetwork.network.broadcast_address - 3) + '/' + containerNetworkCIDR)):
    TESTS_PASSED.append("Modify container subnet: static-ips.conf tredlyDNS")
else:
    print(stdErrString)
    TESTS_FAILED.append("Modify container subnet: static-ips.conf tredlyDNS")

if (staticIPsChecks.checkOption('tredlyCC', str(containerNetwork.network.broadcast_address - 4) + '/' + containerNetworkCIDR)):
    TESTS_PASSED.append("Modify container subnet: static-ips.conf tredlyCC")
else:
    print(stdErrString)
    TESTS_FAILED.append("Modify container subnet: static-ips.conf tredlyCC")

# TODO: check IPFW
# table 7 - hosts private ip
line = subprocess.getoutput('cat /usr/local/etc/ipfw.table.7 | grep "' + hostPrivateIP +'$"').strip()
if (len(line) > 0):
    value = line.split()[-1]
    if(value == hostPrivateIP):
        TESTS_PASSED.append("Modify container subnet: IPFW table 7")
    else:
        print(stdErrString)
        TESTS_FAILED.append("Modify container subnet: IPFW table 7")
else:
    print(stdErrString)
    TESTS_FAILED.append("Modify container subnet: IPFW table 7 failed to get value")
        
# table 10 - hosts private ocntaienr subnet
line = subprocess.getoutput('cat /usr/local/etc/ipfw.table.10 | grep "' + (containerNetworkIP + '/' + containerNetworkCIDR) +'$"').strip()
if (len(line) > 0):
    print(line)
    value = line.split()[-1]
    if(value == (containerNetworkIP + '/' + containerNetworkCIDR)):
        TESTS_PASSED.append("Modify container subnet: IPFW table 10")
    else:
        print(stdErrString)
        TESTS_FAILED.append("Modify container subnet: IPFW table 10")
else:
    print(stdErrString)
    TESTS_FAILED.append("Modify container subnet: IPFW table 10 failed to get value")
    
# table 11 - hosts private container subnet interface name
line = subprocess.getoutput('cat /usr/local/etc/ipfw.table.11 | grep "' + containerNetworkInterface +'$"').strip()
if (len(line) > 0):
    value = line.split()[-1]
    if(value == containerNetworkInterface):
        TESTS_PASSED.append("Modify container subnet: IPFW table 11")
    else:
        print(stdErrString)
        TESTS_FAILED.append("Modify container subnet: IPFW table 11")
else:
    print(stdErrString)
    TESTS_FAILED.append("Modify container subnet: IPFW table 11 failed to get value")

################

publicInterface = 'em0'
publicIP = '192.168.0.1'
publicCIDR = '24'
publicIPInterface = ipaddress.IPv4Interface(publicIP + '/' + publicCIDR)
publicNetmask = str(publicIPInterface.with_netmask).split('/', 1)[-1]


e_header("Running config host network test")
cmd = ['tredly', 'config', 'host', 'network', publicInterface, str(publicIPInterface.ip) + '/' + publicCIDR, '192.168.0.1']
process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
stdOut, stdErr = process.communicate()
stdOutString = stdOut.decode("utf-8", "replace")
stdErrString = stdErr.decode('utf-8', 'replace')
print(stdOutString)
print(cmd)
if (process.returncode != 0):
    TESTS_FAILED.append("Failed to run tredly config host network command")
    print(stdErrString)
    
else: 
    # get the interface for the bridge
    actualPublicInterfaceIP = getInterfaceIP4('em0')
    
    if (actualPublicInterfaceIP == str(publicIPInterface.ip)):
        TESTS_PASSED.append("Modify host network: public interface IP")
    else:
        TESTS_FAILED.append("Modify host network: public interface IP")
    
    if (rcConfChecks.checkOption('ifconfig_' + publicInterface, '"inet ' + str(publicIPInterface.ip) + ' netmask ' + publicNetmask + '"')):
        TESTS_PASSED.append("Modify host network: rc.conf ifconfig")
    else:
        print(stdErrString)
        TESTS_FAILED.append("Modify host network: rc.conf ifconfig")
    
    if (sshChecks.checkOption('ListenAddress', str(publicIPInterface.ip)), ' '):
        TESTS_PASSED.append("Modify host network: sshd_config ListenAddress")
    else:
        print(stdErrString)
        TESTS_FAILED.append("Modify host network: sshd_config ListenAddress")
    
    if (configChecks.checkOption('wifPhysical', publicInterface)):
        TESTS_PASSED.append("Modify container subnet: tredly-host.conf wifPhysical")
    else:
        print(stdErrString)
        TESTS_FAILED.append("Modify container subnet: tredly-host.conf wifPhysical")

    # table 5 - hosts public IP
    line = subprocess.getoutput('cat /usr/local/etc/ipfw.table.5 | grep "' + str(publicIPInterface.ip) +'$"').strip()
    if (len(line) > 0):
        value = line.split()[-1]
        if(value == str(publicIPInterface.ip)):
            TESTS_PASSED.append("Modify container subnet: IPFW table 5")
        else:
            print(stdErrString)
            TESTS_FAILED.append("Modify container subnet: IPFW table 5")
    else:
        print(stdErrString)
        TESTS_FAILED.append("Modify container subnet: IPFW table 5 failed to get value")

    # table 6 - hosts public interfac ename
    line = subprocess.getoutput('cat /usr/local/etc/ipfw.table.6 | grep "' + publicInterface +'$"').strip()
    if (len(line) > 0):
        value = line.split()[-1]
        if(value == publicInterface):
            TESTS_PASSED.append("Modify container subnet: IPFW table 6")
        else:
            print(stdErrString)
            TESTS_FAILED.append("Modify container subnet: IPFW table 6")
    else:
        print(stdErrString)
        TESTS_FAILED.append("Modify container subnet: IPFW table 6 failed to get value")



##################################

hostGatewayIP = '192.168.0.254'


e_header("Running config host network test")
cmd = ['tredly', 'config', 'host', 'gateway', '192.168.0.254']
process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
stdOut, stdErr = process.communicate()
stdOutString = stdOut.decode("utf-8", "replace")
stdErrString = stdErr.decode('utf-8', 'replace')
print(stdOutString)
print(cmd)
if (process.returncode != 0):
    TESTS_FAILED.append("Failed to run tredly config host gateway command")
    print(stdErrString)
    
else: 
    # check default gateway was changed
    line = subprocess.getoutput('netstat -rn | grep "^default"').strip()
    if (len(line) > 0):
        value = line.split()[1]
        if(value == hostGatewayIP):
            TESTS_PASSED.append("Modify host gateway: default gateway")
        else:
            print(stdErrString)
            TESTS_FAILED.append("Modify host gateway: default gateway")
    else:
        print(stdErrString)
        TESTS_FAILED.append("Modify host gateway: default gateway failed to get value")

    if (rcConfChecks.checkOption('defaultrouter', '"' + hostGatewayIP + '"')):
        TESTS_PASSED.append("Modify container subnet: rc.conf defaultrouter")
    else:
        print(stdErrString)
        TESTS_FAILED.append("Modify container subnet: rc.conf defaultrouter")


######################

hostHostname = "testhost"

e_header("Running config host hostname test")
cmd = ['tredly', 'config', 'host', 'hostname', hostHostname]
process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
stdOut, stdErr = process.communicate()
stdOutString = stdOut.decode("utf-8", "replace")
stdErrString = stdErr.decode('utf-8', 'replace')
print(stdOutString)
print(cmd)
if (process.returncode != 0):
    TESTS_FAILED.append("Failed to run tredly config host hostname command")
    print(stdErrString)
    
else: 
    # check default gateway was changed
    line = subprocess.getoutput('hostname').strip()
    if (len(line) > 0):
        value = line
        if(value == hostHostname):
            TESTS_PASSED.append("Modify host hostname: live hostname")
        else:
            print(stdErrString)
            TESTS_FAILED.append("Modify host hostname: live hostname")
    else:
        print(stdErrString)
        TESTS_FAILED.append("Modify host hostname: live hostname failed to get value")

    if (rcConfChecks.checkOption('hostname', '"' + hostHostname + '"')):
        TESTS_PASSED.append("Modify container hostname: rc.conf hostname")
    else:
        print(stdErrString)
        TESTS_FAILED.append("Modify container hostname: rc.conf hostname")


hostDNS = ['8.8.8.8', '8.8.4.4']

e_header("Running config host DNS test")
cmd = ['tredly', 'config', 'host', 'DNS', ",".join(hostDNS)]
print(cmd)
process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
stdOut, stdErr = process.communicate()
stdOutString = stdOut.decode("utf-8", "replace")
stdErrString = stdErr.decode('utf-8', 'replace')
print(stdOutString)
if (process.returncode != 0):
    TESTS_FAILED.append("Failed to run tredly config host hostname command")
    print(stdErrString)

else: 
    for dns in hostDNS:
        print("'" + dns + "'")
        # check default gateway was changed
        line = subprocess.getoutput('cat /etc/resolv.conf | grep -E ' + dns + '$').strip()

        if (len(line) > 0):
            
            value = line.split()[-1]
            if(value == dns):
                TESTS_PASSED.append("Modify host DNS: /etc/resolv.conf")
            else:
                print(stdErrString)
                TESTS_FAILED.append("Modify host DNS: /etc/resolv.conf " + dns)
        else:
            print(stdErrString)
            TESTS_FAILED.append("Modify host DNS: failed to get value " + dns )

###################################
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
exit(0)