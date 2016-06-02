import sys


import os.path

from objects.tredly.unboundfile import *

unboundFile = UnboundFile('/usr/local/etc/unbound/configs/test')

unboundFile.read()
unboundFile.append('local-data', 'test.com', 'in', 'a', '10.0.0.1', '1111')
unboundFile.append('local-data', 'test.com', 'in', 'a', '10.0.0.1', 'uuid')
unboundFile.append('local-data', 'test.com', 'in', 'a', '10.0.0.1', '2222')
unboundFile.append('local-data', 'test1.com', 'in', 'a', '10.0.0.1', 'uuid')
unboundFile.append('local-data', 'test.com', 'in', 'a', '10.0.0.1', '3333')
unboundFile.append('local-data', 'test2.com', 'in', 'a', '10.0.0.1', 'uuid')
print(len(unboundFile.lines))
print(unboundFile.lines)

# remove the elements for this uuid
unboundFile.removeElementsByUUID('uuid')
print(len(unboundFile.lines))
print(unboundFile.lines)