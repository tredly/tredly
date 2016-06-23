import re
import os
import json
import yaml
from pprint import pprint

from objects.tredly.parser.TredlyParser import TredlyParser
from objects.tredly.tredlyfile import *

class YamlParser(TredlyParser):

    # Action: Reads a RAML tredly file and converts it into a json object
    #
    # Pre:
    # Post: self.filePath (if valid path) has been read in as json
    #
    # Params:
    #
    # Return: json object
    def read(self):

        file = open(self.filePath, 'r')
        self.json = yaml.load(file.read())
        return self.json
