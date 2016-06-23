# Performs network checks
from subprocess import Popen, PIPE
import subprocess
from includes.output import *
import xml.etree.ElementTree as ET

class NetworkChecks:
    
    # Constructor
    def __init__(self, ip4):
        self.ip4 = ip4

    # uses nmap to check if a SINGLE port is open 
    def checkPort(self, protocol, portNum):
        # set up the command for the relevant protocol
        if (protocol == 'tcp'):
            cmd = ['nmap', '-sS','-oX', '-', '-p', str(portNum), self.ip4]
        elif (protocol == 'udp'):
            cmd = ['nmap', '-sU','-oX', '-', '-p', str(portNum), self.ip4]
        
        process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
        stdOut, stdErr = process.communicate()
        stdOutString = stdOut.decode('utf-8')
        stdErrString = stdErr.decode('utf-8')

        if (process.returncode != 0):
            e_error("Failed to run nmap")
            print(stdOutString)
            print(stdErrString)
            print('exitcode: ' + process.returncode)
            exit(process.returncode)
            
        # parse the xml
        xmlRoot = ET.fromstring(stdOutString)
        
        for port in xmlRoot.iter('port'):
            for state in port.iter('state'):
                if (state.attrib['state'] == 'open'):
                    return True
    
        return False
    

    # checks a url with the HTTP protocol
    def checkURL(self, url, websocket = False, expectedStatusCodes = ['200'], interface = 'bridge1'):
        # split up the url
        # eg where url = https://www.test.com:443/path/to/url
        protocol = url.split('://', 1)[0]       # https
        remainingUrl = url.split('://', 1)[-1]  # www.test.com:443/path/to/url

        hostnameWithPort = remainingUrl.split('/', 1)[0]    # www.test.com:443
        
        # check if a port was received
        if (':' in hostnameWithPort):
            # it was so split it out
            hostname = hostnameWithPort.split(':', 1)[0]
            port = hostnameWithPort.split(':', 1)[-1]
        else:
            hostname = hostnameWithPort
            # no port received, work it out based off the protocol
            if (protocol == 'https'):
                port = "443"
            else:
                port = "80"
        
        # set up the command depending if its a websocket or standard url
        if (websocket):
           cmd = ['curl', 
                   '-I',
                   '-k', 
                   '--connect-timeout', 
                   '10', 
                   '--interface', 
                   interface, 
                   '--resolve', 
                   hostname + ':' + port + ':' + self.ip4, 
                   '-i',
                   '-N',
                   '-H',
                   "Connection: Upgrade",
                   '-H',
                   "Upgrade: websocket",
                   '-H',
                   "Host: " + hostname,
                   '-H',
                   "Origin: " + protocol + "://" + hostname,
                   url
                  ]
        else:
            cmd = ['curl', 
                   '-I',
                   '-k', 
                   '--connect-timeout', '10', 
                   '--interface', interface, 
                   '--resolve', hostname + ':' + port + ':' + self.ip4, 
                   url
                  ]
        process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
        stdOut, stdErr = process.communicate()
        stdOutString = stdOut.decode('utf-8')
        stdErrString = stdErr.decode('utf-8')
        if (process.returncode != 0):
            e_error("Failed to connect to url " + proto + '://' + url)
            return None
    
        # look for HTTP response
        for line in stdOutString.splitlines():
            if (line.startswith('HTTP/')):
                return line.split()[1]
    
        return None
    
    
    # maxfilesize in megabytes
    def checkUrlMaxFileSize(self, url, maxFileSize):
        # split up the url
        # eg where url = https://www.test.com:443/path/to/url
        protocol = url.split('://', 1)[0]       # https
        remainingUrl = url.split('://', 1)[-1]  # www.test.com:443/path/to/url

        hostnameWithPort = remainingUrl.split('/', 1)[0]    # www.test.com:443
        
        # check if a port was received
        if (':' in hostnameWithPort):
            # it was so split it out
            hostname = hostnameWithPort.split(':', 1)[0]
            port = hostnameWithPort.split(':', 1)[-1]
        else:
            hostname = hostnameWithPort
            # no port received, work it out based off the protocol
            if (protocol == 'https'):
                port = "443"
            else:
                port = "80"
        
        fileSize = int(maxFileSize) * 1024
        
        # test two cases - one 1mb below the max file size, and another 1mb above
        testFileSizes = []
        testFileSizes.append(fileSize-1024)
        testFileSizes.append(fileSize+1024)
        
        for testFileSize in testFileSizes:
            # creeate a temporary file to upload using curl
            cmd = ['dd', 
                   'if=/dev/zero',
                   'of=/tmp/tredlytest.img', 
                   'bs=1024', 
                   'count=0', 
                   'seek=' + str(testFileSize)
                  ]
            
            process = Popen(cmd,  stdin=PIPE, stdout=PIPE, stderr=PIPE)
            stdOut, stdErr = process.communicate()
            stdOutString = stdOut.decode('utf-8')
            stdErrString = stdErr.decode('utf-8')
            if (process.returncode != 0):
                e_error("Failed to create temporary file")
                return None
    
            uploadResult = subprocess.getoutput('curl --form upload=@/tmp/tredlytest.img  --interface bridge1 -k --resolve ' + hostname + ':' + port + ':' + self.ip4 + ' ' + url)

            # look for HTTP response
            for line in stdOutString.splitlines():
                if (line.startswith('HTTP/')):
                    responseCode = line.split()[1]
                    
                    if (responseCode == '413') and (testFileSize < fileSize):
                        return False
                    elif (responseCode != '413' and (testFileSize > fileSize)):
                        return False
        return True
            