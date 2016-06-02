import sys


import os.path

from objects.tredly.tredlyhost import *

t = TredlyHost()

containerGroupIps = t.getContainerGroupContainerIps('mygroup', 'stage')

print(containerGroupIps)

partitionNames = t.getPartitionNames()

print(partitionNames)