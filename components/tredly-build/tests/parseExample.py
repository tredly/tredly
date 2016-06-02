import sys

import os.path
import builtins

# get the path to the script
builtins.scriptDirectory = os.path.dirname(os.path.realpath(__file__))

# set environment up the same way as tredly-build
sys.path.insert(0, builtins.scriptDirectory)
sys.path.insert(0, builtins.scriptDirectory + "/tests")
sys.path.insert(0, builtins.scriptDirectory + "/actions")
sys.path.insert(0, builtins.scriptDirectory + "/includes")
sys.path.insert(0, builtins.scriptDirectory + "/objects")
sys.path.insert(0, builtins.scriptDirectory + "/tests")
builtins.tredlyConfDirectory = builtins.scriptDirectory + "/conf"
builtins.tredlyJsonDirectory = builtins.scriptDirectory + "/json"

from objects.tredly.tredlyfile import *
if (len(sys.argv) is 2):
    file = sys.argv[1]
else:
    file = "tests/cases/TredlyFile"

newFilename = (file.split(".")[:1][0].split("/")[-1] + ".json")
path = file.split("/")[0:-2]
path.append("generated")

if not os.path.exists(os.path.join(*path)):
    os.makedirs(os.path.join(*path))

path.append(newFilename)
t = TredlyFile(file)
t.write(os.path.join(*path))
print("Wrote file", os.path.join(*path))
