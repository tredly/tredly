# A class to represent an Unbound File
import os.path
import re
from subprocess import Popen, PIPE

class UnboundFile:
    # Constructor
    def __init__(self, filePath):
        self.filePath = filePath
        self.lines = []

    # Action: reads unbound file, and stores parsed lines to self
    #
    # Pre:
    # Post:
    #
    # Params:
    #
    # Return: Set if exists, False otherwise
    def read(self, clear = True):
        # only read in the data if the file actually exists
        if (self.fileExists()):
            # if clear is set then clear hte array first
            if (clear):
                self.lines = []
            
            # file exists so process it
            with open(self.filePath) as unboundFile:
                for line in unboundFile:
                    # strip off leading and following whitespace
                    line = line.strip()
                    
                    # ignore empty lines
                    if (len(line) > 0):

                        m = re.match("^([\w\-]+)\:\s*\"([A-z\-0-9\.]+)\s+(\w+)\s+(\w+)\s+((?:[0-9]{1,3}\.){3}[0-9]{1,3})\"\s+\#\s+([A-z0-9]+)", line)
        
                        self.append(m.group(1), m.group(2), m.group(3), m.group(4), m.group(5), m.group(6))
        #else:
            #raise Exception("Unbound file does not exist at location '" + self.filePath + "'")

    # append a record to this file
    def append(self, type, domainName, inValue, recordType, ipAddress, uuid):
        self.lines.append({
            'type': type,
            'domainName': domainName,
            'in': inValue,
            'recordType': recordType,
            'ipAddress': ipAddress,
            'uuid': uuid
        })
        
        return True

    # Action: removes all elements relating to a given uuid
    #
    # Pre: this object exists
    # Post: all elements with given uuid have been removed from self.lines
    #
    # Params: uuid - the uuid to remove
    #
    # Return: True if succes, False otherwise
    def removeElementsByUUID(self, uuid):
        # dont do anything if the list is empty
        if (len(self.lines) == 0):
            return True
        
        # create a new list
        newList = []
        
        # loop over the list
        for element in self.lines:
            # check if this element has the same uuid
            if (element['uuid'] != uuid):
                # not equal to our uuid so add to new list
                newList.append(element)
        
        # set the lines to the updated element
        self.lines = newList
        
        return True

    # Action: checks whether the path to the unbound file exists or not
    #
    # Pre:
    # Post:
    #
    # Params:
    #
    # Return: True if exists, False otherwise
    def fileExists(self):
        return os.path.isfile(self.filePath)

    # Action: writes an unbound file.
    #
    # Pre:
    # Post:
    #
    # Params:
    #
    # Return: True if successful, False otherwise
    def write(self, deleteEmpty = True):
        
        # if self.lines is length of 0 then delete the file
        if (len(self.lines) == 0) and (deleteEmpty):
            # delete it
            try:
                os.remove(self.filePath)
            except FileNotFoundError:
                pass
        else:
            try:
                with open(self.filePath, 'w') as unbound_config:
                    for line in self.lines:
                        # form the line
                        text = ''
                        text += line['type'] + ': "'
                        text += line['domainName'] + " "
                        text += line['in'] + " "
                        text += line['recordType'] + " "
                        text += line['ipAddress'] + '" # '
                        text += line['uuid']
                        
                        # write the line to the file
                        print(text, file=unbound_config)
            except IOError:
                return False
        
        return True
    