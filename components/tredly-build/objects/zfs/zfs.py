# Purpose: Facilitates access to ZFS datasets and properties

from includes.output import *
from subprocess import Popen, PIPE;

class ZFSDataset:
    # Constructor
    def __init__(self, dataset, mountPoint = None):
        self.dataset = dataset
        self.mountPoint = mountPoint

    # Action: check if ZFS dataset exists
    #
    # Pre: 
    # Post: 
    #
    # Params: 
    #
    # Return: True if exists, False otherwise
    def exists(self):
        process = Popen(['zfs', 'list', self.dataset],  stdin=PIPE, stdout=PIPE, stderr=PIPE);
        stdOut, stdErr = process.communicate();
        rc = process.returncode;
        
        # check the exit code
        if (rc == 0):
            return True;
        else:
            return False;
    
    # Action: create a ZFS dataset
    #
    # Pre: 
    # Post: dataset exists
    #
    # Params: 
    #
    # Return: True if dataset now exists, False otherwise
    def create(self):
        # make sure the dataset already exists
        if (self.exists()):
            return True;
        
        # create the zfs dataset with the given mountpoint
        process = Popen(['zfs', 'create', '-pu', '-o', 'mountpoint=' + self.mountPoint, self.dataset],  stdin=PIPE, stdout=PIPE, stderr=PIPE);
        stdOut, stdErr = process.communicate();
        rc = process.returncode;
        
        # check exit code from zfs create
        if (rc != 0):
            # failed so return
            return False;
        
        return True;

    # Action: destroy a ZFS dataset
    #
    # Pre: 
    # Post: dataset does not exist
    #
    # Params: recursive - whether or not to delete this ZFS datasets children
    #
    # Return: True if succeeded, False otherwise
    def destroy(self, recursive = False):
        # make sure the dataset already exists
        if (not self.exists()):
            return True
        
        # destroy the zfs dataset
        if (recursive):
            cmd = ['zfs', 'destroy', '-rf', self.dataset]
        else:
            cmd = ['zfs', 'destroy', '-f', self.dataset]
        process = Popen(cmd, stdin=PIPE, stdout=PIPE, stderr=PIPE)
        stdOut, stdErr = process.communicate()
        
        # check exit code from zfs destroy
        if (process.returncode != 0):
            e_error("Failed to destroy dataset " + self.dataset)
            print(stdErr)
            # failed so return
            return False
        
        # remove the directory,make sure it has a value and isnt the root directory!
        if (self.mountPoint is not None) and (self.mountPoint != '/'):
            cmd = ['rm', '-rf', self.mountPoint]
            process = Popen(cmd, stdin=PIPE, stdout=PIPE, stderr=PIPE)
            stdOut, stdErr = process.communicate()

        # check exit code from rm
        return (process.returncode == 0)

    # Action: mount a ZFS dataset
    #
    # Pre: 
    # Post: dataset has been mounted
    #
    # Params: 
    #
    # Return: True if succeeded, False otherwise
    def mount(self):
        # make sure the dataset already exists
        if (not self.exists()):
            return False
        
        # create the zfs dataset with the given mountpoint
        process = Popen(['zfs', 'mount', self.dataset],  stdin=PIPE, stdout=PIPE, stderr=PIPE)
        stdOut, stdErr = process.communicate()
        rc = process.returncode
        
        # check exit code from zfs create
        if (rc != 0):
            # failed so return
            return False
        
        return True

    # Action: get a property from a zfs dataset
    #
    # Pre: 
    # Post: requested property has been returned
    #
    # Params: property - the property to request from the ZFS Dataset
    #
    # Return: value from ZFS, None if failed
    def getProperty(self, property):
        cmd = ['zfs', 'get', '-H', '-o', 'value', property, self.dataset]
        process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
        stdOut, stdErr = process.communicate()
        rc = process.returncode
        
        # check the exit code
        if (rc == 0):
            # executed successfully
            return stdOut.decode(encoding='UTF-8').rstrip()
        else:
            # command failed
            return None
    
    # Action: get a property from a zfs dataset recursively
    #
    # Pre: 
    # Post: requested property has been returned as a list
    #
    # Params: property - the property to request from the ZFS Dataset
    #
    # Return: List
    def getPropertyRecursive(self, property):
        cmd = ['zfs', 'get', '-H', '-o', 'value', '-r', property, self.dataset]
        process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
        stdOut, stdErr = process.communicate()
        
        stdOutString = stdOut.decode("utf-8").strip()

        # check the exit code
        if (process.returncode == 0):
            # executed successfully so loop over the results and create a list of them
            results = []
            # loop over lines
            for line in stdOutString.splitlines():
                # make sure its a valid value
                if (line != '-'):
                    results.append(line)
            return results
        
        else:
            # command failed
            return None
        
    # Action: get a property from a zfs dataset
    #
    # Pre: 
    # Post: requested property has been returned
    #
    # Params: property - the property to set
    #         value - the value to set it to
    #
    # Return: True if succeeded, False otherwise
    def setProperty(self, property, value):
        if (value is None):
            value = '-'
        
        cmd = ['zfs', 'set', property + '=' + value, self.dataset]
        process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE);\
        stdOut, stdErr = process.communicate()
        rc = process.returncode

        # check the exit code
        if (rc == 0):
            # executed successfully
            return True
        else:
            print(str(stdErr))
            # command failed
            return False

    # Action: add a value to a "property array"
    #
    # Pre: 
    # Post: requested property has been added at the requested location
    #
    # Params: 
    #
    # Return: True if succeeded, False otherwise
    def appendArray(self, property, value):
        # the following commands are piped together
        zfsCmd = ['zfs', 'get', '-H', '-o', 'property,value', 'all', self.dataset]
        grepCmd = ['grep', '-F', property]
        sedCmd = ['sed', 's/^' + property + '://']
        sortCmd = ['sort', '-k', '1', '-n']
        
        zfsResult = Popen(zfsCmd, stdout=PIPE)
        grepResult = Popen(grepCmd, stdin=zfsResult.stdout, stdout=PIPE)
        sedResult = Popen(sedCmd, stdin=grepResult.stdout, stdout=PIPE)
        sortResult = Popen(sortCmd, stdin=sedResult.stdout, stdout=PIPE)
        stdOut, stdErr = sortResult.communicate()

        zfsResult.wait()
        
        # convert stdout to string
        stdOutString = stdOut.decode("utf-8").strip()

        # we had some results returned so find the highest index
        if (len(stdOutString) > 0):
            # get the last line since we've already sorted it
            lastLine = stdOutString.splitlines()[-1]

            # split off the highest index
            index = int(lastLine.split()[0])
            
            # increment by one
            index += 1
        else:
            index = 0

        # set the property
        return self.setProperty(property + ':' + str(index), value)

    # Action: gets a dict of items on this dataset
    #
    # Pre: 
    # Post: 
    #
    # Params: property - the property to search for
    #
    # Return: dict of zfs values
    def getArray(self, property):
        # the following commands are piped together
        zfsCmd = ['zfs', 'get', '-H', '-o', 'property,value', 'all', self.dataset]
        grepCmd = ['grep', '-F', property + ':']
        sedCmd = ['sed', 's/^' + property + '://']
        sortCmd = ['sort', '-k', '1', '-n']
        
        zfsResult = Popen(zfsCmd, stdout=PIPE)
        grepResult = Popen(grepCmd, stdin=zfsResult.stdout, stdout=PIPE)
        sedResult = Popen(sedCmd, stdin=grepResult.stdout, stdout=PIPE)
        sortResult = Popen(sortCmd, stdin=sedResult.stdout, stdout=PIPE)
        stdOut, stdErr = sortResult.communicate()

        zfsResult.wait()
        
        # convert stdout to string
        stdOutString = stdOut.decode("utf-8").strip()

        # an array to hold our results
        returnArray = {}

        # loop over the results
        for line in stdOutString.splitlines():
            
            # split out the key and value
            key = line.split()[0]
            value = line.split()[1]
            
            # add it to the array
            returnArray[key] = value
        
        return returnArray

    def unsetArray(self, property):
        array = self.getArray(property)
        
        # loop over the results, deleting everything
        for key,value in array.items():
            # remove the item
            #zfs inherit -r "${_property}:${i}" "${_dataset}"
            print('unsetting' + key)
            result = Popen(['zfs', 'inherit', '-r', property + ':' + key, self.dataset], stdout=PIPE)
            stdOut, stdErr = result.communicate()
            print('done')
            # check return code
            if (result.returncode != 0):
                e_error("An error occurred when deleting from ZFS")
                return False

        return True
