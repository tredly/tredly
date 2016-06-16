# A class to represent an layer 4 proxy file
import os.path
import re
from subprocess import Popen, PIPE

class Layer4ProxyFile:

    # Constructor
    def __init__(self, filePath):
        self.filePath = filePath
        self.preamble = ''
        self.lines = []

    # Action: reads layer 4 proxy file, and stores parsed lines to self
    #
    # Pre:
    # Post:
    #
    # Params: clear - clear the elements before reading
    #
    # Return: True if success, False otherwise
    def read(self, clear = True):
        # only read in the data if the file actually exists
        if (self.fileExists()):
            # if clear is set then clear hte array first
            if (clear):
                self.lines = []
            
            # file exists so process it
            with open(self.filePath) as l4proxyFile:
                i = 0
                
                for line in l4proxyFile:
                    # strip off leading and following whitespace
                    line = line.strip()
                    # ignore empty lines
                    if (len(line) > 0):
                        # look for a line we are interested in
                        #regex = '^\w+\s+(tcp|udp)\s+([^:]+):(\d+)\s(\d+)\s+[\\\\\s]*#\s+(\w+)$'
                        regex = '^\w+\s+(tcp|udp)\s+([^:]+):(\d+)\s(\d+)\s+`#\s+(\w+)`\s*[\\\\]*$'
                        m = re.match(regex, line)

                        # check if we found a match
                        if (m is not None):
                            self.append(m.group(5), m.group(1), m.group(4), m.group(2), m.group(3))
                        else:
                            # if this isnt the first line then add a newline
                            if (i > 0):
                                self.preamble += "\n"
                                
                            # add it to the preamble
                            self.preamble += line
                    
                    # increment hte counter
                    i += 1
        else:
            return False
        
        return True

    # Action: append a value to our proxy rules
    #
    # Pre: 
    # Post: given values have been added as a proxy rule
    #
    # Params: uuid - the container uuid. If set to None, then applies to host
    #         protocol - the protocol to use
    #         sourcePort - the source port to forward from
    #         destHost - the destination host to send this traffic to
    #         destPort - the destination port to send this traffic to 
    #
    # Return: True if exists, False otherwise
    def append(self, uuid, protocol, sourcePort, destHost, destPort):
        # only append if the source and dest ports dont exist to prevent errors
        if (not self.srcPortExists(sourcePort)) and (not self.destPortExists(destPort)):
            # append to our dict
            self.lines.append({
                'uuid': uuid,
                'protocol': protocol,
                'destHost': destHost,
                'destPort': destPort,
                'sourcePort': sourcePort
            })
            
            return True
        else:
            return False

    # Action: checks if the given port exists as a source port already
    #
    # Pre:
    # Post:
    #
    # Params: srcPort - the port to check for
    #
    # Return: True if exists, False otherwise
    def srcPortExists(self, srcPort):
        # loop over lines looking for source port
        for line in self.lines:
            if (line['sourcePort'] == srcPort):
                return True
        return False

    # Action: checks if the given port exists as a destination port already
    #
    # Pre: 
    # Post: 
    #
    # Params: srcPort - the port to check for
    #
    # Return: True if exists, False otherwise
    def destPortExists(self, srcPort):
        # loop over lines looking for source port
        for line in self.lines:
            if (line['destPort'] == srcPort):
                return True
        return False

    # Action: removes all elements relating to a given uuid
    #
    # Pre:
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

    # Action: checks whether the path to the layer4proxy file exists or not
    #
    # Pre:
    # Post:
    #
    # Params:
    #
    # Return: True if exists, False otherwise
    def fileExists(self):
        return os.path.isfile(self.filePath)

    # Action: writes a layer 4 proxy file.
    #
    # Pre:
    # Post: the self.lines object has been written to the layer 4 proxy file in the layer 4 proxy format
    #
    # Params:
    #
    # Return: True if successful, False otherwise
    def write(self):
        try:
            with open(self.filePath, 'w') as l4proxyFile:
                print(self.preamble, file=l4proxyFile)
                
                for i, line in enumerate(self.lines):
                    # form the line
                    text = 'redirect_port ' + line['protocol'] + " " + line['destHost'] + ':' + str(line['destPort']) + " " + str(line['sourcePort']) + ' `# ' + line['uuid'] + '`'

                    # add the bash line connector if this isnt the last line
                    if (i < (len(self.lines)-1)):
                         text += " \\"

                    # write the line to the file
                    print(text, file=l4proxyFile)
        except IOError:
            return False
        
        return True
    
    # Action: reload the layer 4 proxy data from self.filePath
    #
    # Pre: 
    # Post: ipfw rules have been applied to container or host
    #
    # Params: 
    #
    # Return: True if succeeded, False otherwise
    def reload(self):
        # run the script that this object represents
        process = Popen(['sh', self.filePath], stdin=PIPE, stdout=PIPE, stderr=PIPE)
        stdOut, stdErr = process.communicate()
        return (process.returncode == 0)