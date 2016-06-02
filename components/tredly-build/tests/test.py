import sys


import os.path
# sys.path.insert(0, os.path.dirname(__file__) + "/tests")
from objects.tredly.tredlyfile import *
if (len(sys.argv) is 2):
    file = sys.argv[1]
else:
    file = "TredlyFile"

t = TredlyFile(file)
t.read()