# A class to represent an Unbound File
import os.path
import re

class ResolvConfFile:
    # Constructor
    def __init__(self, filePath = '/etc/resolv.conf', search = [], servers = []):
        self.filePath = filePath
        self.search = search
        self.nameservers = servers
    
    # Action: reads resolv.conf file, and stores parsed lines to self
    #
    # Pre: this object exists
    # Post: data has been read if file exists
    #
    # Params: clear - whether or not to clear this object when re-reading
    #
    # Return: True if success, False otherwise
    def read(self, clear = True):
        # only read in the data if the file actually exists
        if (self.fileExists()):
            # if clear is set then clear hte array first
            if (clear):
                self.search = []
                self.nameservers = []
            
            # file exists so process it
            with open(self.filePath) as resolvConf:
                for line in resolvConf:
                    # strip off leading and following whitespace
                    line = line.strip()
                    
                    # ignore empty lines
                    if (len(line) > 0):
                        lineList = line.split()
                        if (lineList[0] == "search"):
                            # remove the first element as we arent interested in it
                            del lineList[0]
                            
                            # set the linelist as the search list
                            self.search = lineList

                        elif (lineList[0] == "nameserver"):
                            # append the second element to the search list
                            self.nameservers.append(lineList[1])

            return True
        else:
            return False

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

    # Action: writes out a resolv.conf file
    #
    # Pre: this object exists
    # Post: this object has been written to self.filePath in the resolv.conf format
    #
    # Params:
    #
    # Return: True if successful, False otherwise
    def write(self):
        try:
            with open(self.filePath, 'w') as resolvConf:
                searchLine = 'search'
                for search in self.search:
                    # append the dns search path to the variable
                    searchLine = searchLine + ' ' + search
                
                # print it to the file
                print(searchLine, file=resolvConf)
                
                # loop over the nameservers, printing one per line to the file
                for nameserver in self.nameservers:
                    # write the line to the file
                    print('nameserver ' + nameserver, file=resolvConf)
                
                return True
        except IOError:
            return False
        return False
    