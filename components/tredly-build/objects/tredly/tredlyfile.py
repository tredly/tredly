import importlib
from pprint import pprint
import os.path
#from objects.vendor.jsonschema.jsonschema.validator import *
#from jsonschema import validate
import json
import builtins
from includes.output import *


# A class to handle the loading of Tredlyfiles. This class has been designed in such a way that all data is parsed to JSON.
# This allows us to load any type of file we wish without having to change the internals of Tredly
class TredlyFile:

    # constructor
    def __init__(self,filePath):
        self.filePath = filePath
        self.__getParser()

        # parse and load
        self.json = self.parser.read()
        self.parser.validate()

        # set the working directory
        self.fileLocation = os.path.dirname(filePath)

    # Action: Find the correct parser for this file type
    #
    # Pre: this object exists
    # Post: self.parser assigned the correct parser
    #
    # Params:
    #
    # Return: True if succeeded, False otherwise
    def __getParser(self):
        file = self.filePath.split("/")[-1]
        ext = file.split(".")[-1]

        try:
            # dynamically load the module
            mod = importlib.import_module("objects.tredly.parser." + ext.lower() + "file")
        except ImportError as e:
            raise Exception("No Tredly parser for type '" + ext + "'")
            return False

        parser = getattr(mod , ext[0].upper() + ext[1:].lower() +"Parser")
        self.parser = parser(self.filePath)

        return True

    # Action: reads the given config file and outputs JSON data
    #
    # Pre: this object exists
    # Post:
    #
    # Params:
    #
    # Return: JSON data
    def read(self):
        self.parser.read()

    def write(self, filepath):
        f = open(filepath, 'w+')
        f.write(str(self))
        f.close()
        
    def __str__(self):
        return json.dumps(self.json, indent=4)