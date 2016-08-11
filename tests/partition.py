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
#from testobjects.networkchecks import *
#from testobjects.firewallchecks import *
from objects.zfs.zfs import ZFSDataset

testName = "Create/Modify/Delete Partition"
partitionName="test-partition"

# some lists for passed/failed test info
TESTS_PASSED = []
TESTS_FAILED = []

createCPU = "100%"
createRAM = "1G"
createHDD = "1G"
createWhitelist = ["1.1.1.1","2.2.2.2"]

# create the partition
cmd = ['tredly', 'create','partition', partitionName, 'CPU=' + createCPU, 'RAM=' + createRAM, "HDD=" + createHDD, "ipv4Whitelist=" + ",".join(createWhitelist)]
process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
stdOut, stdErr = process.communicate()

stdOutString = stdOut.decode("utf-8", "replace")
stdErrString = stdErr.decode('utf-8', 'replace')
print(stdOutString)
if (process.returncode == 0):
    TESTS_PASSED.append("Create Partition")
else:
    e_error("Failed to create partition")
    print(stdErrString)
    TESTS_FAILED.append("Create Partition")

# check that the values were set
line = subprocess.getoutput('zfs get -H -o value quota zroot/tredly/ptn/' + partitionName).strip()
if (createHDD == line):
    TESTS_PASSED.append("Create Partition: set maxHdd")
else:
    TESTS_FAILED.append("Create Partition: set maxHdd")

line = subprocess.getoutput('zfs get -H -o value com.tredly:maxcpu zroot/tredly/ptn/' + partitionName).strip()
if (createCPU == line):
    TESTS_PASSED.append("Create Partition: set maxCpu")
else:
    TESTS_FAILED.append("Create Partition: set maxCpu")

line = subprocess.getoutput('zfs get -H -o value com.tredly:maxram zroot/tredly/ptn/' + partitionName).strip()
if (createRAM == line):
    TESTS_PASSED.append("Create Partition: set maxRam")
else:
    TESTS_FAILED.append("Create Partition: set maxRam")

# use zfs object to get the array
partitionZFS = ZFSDataset('zroot/tredly/ptn/' + partitionName)
whitelistZFS = partitionZFS.getArray('com.tredly.ptn_ip4whitelist')
commonElements = set(createWhitelist).intersection(whitelistZFS.values())
if (len(commonElements) == len(createWhitelist)):
    TESTS_PASSED.append("Create Partition: set whitelist")
else:
    TESTS_FAILED.append("Create Partition: set whitelist")


############################

modifyPartitionName = partitionName + '-renamed'
modifyCPU = "200%"
modifyRAM = "2G"
modifyHDD = "2G"
modifyWhitelist = 'clear'

# modify the partition
cmd = ['tredly', 'modify','partition', partitionName, "partitionName=" + modifyPartitionName, 'CPU=' + modifyCPU, 'RAM=' + modifyRAM, "HDD=" + modifyHDD, "ipv4Whitelist=" + modifyWhitelist]

process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
stdOut, stdErr = process.communicate()
stdOutString = stdOut.decode('utf-8', 'replace')
stdErrString = stdErr.decode('utf-8', 'replace')
print(stdOutString)
if (process.returncode != 0):
    e_error("Failed to modify partition")
    print(stdErrString)
    TESTS_FAILED.append("Modify Partition")
else:
    TESTS_PASSED.append("Modify Partition")


# check that the values were set
line = subprocess.getoutput('zfs get -H -o value quota zroot/tredly/ptn/' + modifyPartitionName).strip()
if (modifyHDD == line):
    TESTS_PASSED.append("Modify Partition: set maxHdd")
else:
    TESTS_FAILED.append("Modify Partition: set maxHdd")

line = subprocess.getoutput('zfs get -H -o value com.tredly:maxcpu zroot/tredly/ptn/' + modifyPartitionName).strip()
if (modifyCPU == line):
    TESTS_PASSED.append("Modify Partition: set maxCpu")
else:
    TESTS_FAILED.append("Modify Partition: set maxCpu")

line = subprocess.getoutput('zfs get -H -o value com.tredly:maxram zroot/tredly/ptn/' + modifyPartitionName).strip()
if (modifyRAM == line):
    TESTS_PASSED.append("Modify Partition: set maxRam")
else:
    TESTS_FAILED.append("Modify Partition: set maxRam")

# use zfs object to get the array
partitionZFS = ZFSDataset('zroot/tredly/ptn/' + modifyPartitionName)
whitelistZFS = partitionZFS.getArray('com.tredly.ptn_ip4whitelist')

if (modifyWhitelist == 'clear'):
    if (len(whitelistZFS) == 0):
        TESTS_PASSED.append("Modify Partition: clear whitelist")
    else:
        TESTS_FAILED.append("Modify Partition: clear whitelist")
        print(whitelistZFS)
else:
    commonElements = set(modifyWhitelist).intersection(whitelistZFS.values())

    if (len(commonElements) != len(createWhitelist)):
        TESTS_PASSED.append("Modify Partition: set whitelist")
    else:
        TESTS_FAILED.append("Modify Partition: set whitelist")

#################

# destroy the partition
yesProcess = Popen(['yes', 'y'], stdout=PIPE)
process = Popen(['tredly', 'destroy','partition', partitionName + '-renamed'], stdin=yesProcess.stdout, stdout=PIPE, stderr=PIPE)

stdOut, stdErr = process.communicate()
stdOutString = stdOut.decode('utf-8', 'replace')
stdErrString = stdErr.decode('utf-8', 'replace')
print(stdOutString)
if (process.returncode != 0):
    e_error("Failed to destroy partition")
    print(stdErrString)
    TESTS_FAILED.append("Destroy Partition")
else:
    TESTS_PASSED.append("Destroy Partition")

line = subprocess.getoutput('zfs list -H zroot/tredly/ptn/' + modifyPartitionName).strip()
if (('zroot/tredly/ptn/' + modifyPartitionName) == line.split()[0]):
    TESTS_FAILED.append("Delete Partition: ZFS destroy")
else:
    TESTS_PASSED.append("Delete Partition: ZFS destroy")

###############

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

# exit with an errorcode if we had failed tests
if (len(TESTS_FAILED) > 0):
    exit(1)
else:
    exit(0)
