import sys


import os.path

from objects.zfs.zfs import *

property = 'com.tredly.testarray'

zfs = ZFSDataset('zroot/tredly')

zfs.appendArray(property, 'zero')
zfs.appendArray(property, 'one')
zfs.appendArray(property, 'two')
zfs.appendArray(property, 'three')
zfs.appendArray(property, 'four')

print(zfs.getArray('com.tredly.testarray'))
print('unsetting')
zfs.unsetArray(property)
print('unsetted')
print(zfs.getArray('com.tredly.testarray'))
