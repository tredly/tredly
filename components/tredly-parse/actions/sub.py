# Performs actions requested by the user
import builtins
from subprocess import Popen, PIPE
import urllib.request
import os.path
import time
import argparse

from objects.tredly.tredlyfile import *
from includes.util import *
from includes.defines import *
from includes.output import *

class ActionSub:
    def __init__(self, subject, target, identifier, actionArgs):
        # do some validation
        if (actionArgs['sub'] is None) and (actionArgs['subCleanDots'] is None):
            e_error("Please include some strings to substitute.")
            exit(1)
        
        # go ahead and substitute
        self.substitute(subject, actionArgs['sub'], actionArgs['subCleanDots'])
    
    # sub out the strings
    def substitute(self, srcDir, substitute, substituteAndCleanDots):
        
        if (srcDir is None):
            srcDir = "./"
            
        if (substituteAndCleanDots is None):
             substituteAndCleanDots = []
             
        if (substitute is None):
            substitute = []

        # find the tredlyfile
        tredlyFilePath = findTredlyFile(srcDir)
        e_header("Substituting " + tredlyFilePath)
        # new file in memory
        newFile = ''
        
        # open the file
        with open(tredlyFilePath) as tredlyfile:
            
            for line in tredlyfile:
                line = line.rstrip("\n")

                # split out the line into the part to process and comments
                if ('#' in line):
                    # split it into the part to process and the part to ignore
                    processPart = line.split('#', 1)[0]
                    commentPart = line.split('#', 1)[-1]
                else:
                    processPart = line
                    commentPart = ''

                # sub out anything requested
                for sub in substituteAndCleanDots:
                    if ('=' in sub):
                        needle = sub.split('=', 1)[0]
                        replacement = sub.split('=', 1)[-1]
                        
                        # get the start of the substring
                        subStringStart = processPart.find(needle)
                        if (subStringStart > 0):
                            subStringStart = subStringStart -1
                        
                        # replace the string
                        processPart = processPart.replace(needle, replacement)

                        # if replacement is empty then look to clean up any double dots
                        if (replacement == ''):

                            # look for double dots
                            if (processPart.find('..', subStringStart, (subStringStart + 2)) != -1):
                                # found it so remove one of the dots
                                
                                # turn string into a list so we can address specific chars
                                processPartList = list(processPart)
                                
                                # remove it
                                del processPartList[subStringStart]

                                # turn the list back into a string
                                processPart = "".join(processPartList)

                # sub out anything requested
                for sub in substitute:
                    if ('=' in sub):
                        needle = sub.split('=', 1)[0]
                        replacement = sub.split('=', 1)[-1]
                        
                        # replace the string
                        processPart = processPart.replace(needle, replacement)
                        
                # add the line back together into the new file in memory
                newFile = newFile + processPart
                # check if a comment was on this line
                if (len(commentPart) > 0):
                    newFile = newFile + '#' + commentPart
                    
                newFile = newFile + "\n"

        # overwrite the file
        try:
            # open the file to writing
            with open(tredlyFilePath, 'w') as newTredlyFile:
                # write to the file
                print(newFile, file=newTredlyFile)
                
                e_success()
        except IOError:
            e_error()

