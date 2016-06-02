import sys


import os.path

from objects.layer4proxy.layer4proxyfile import *

l4 = Layer4ProxyFile('/usr/local/etc/ipfw.layer4')
l4.read()
print("PREAMBLE:")
print(l4.preamble)

print("LINES")
print(l4.lines)

#l4.append('uuid', 'protocol', 'sourcePort', 'destHost', 'destPort')
#l4.write()

