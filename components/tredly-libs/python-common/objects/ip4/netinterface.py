# A class to represent a network interface
import random

class NetInterface:

    # Constructor
    def __init__(self, name = None, mac = None):
        self.name = name
        self.mac = mac
        self.ip4Addrs = []
        self.ip6Addrs = []

    
    # Action: Generate a mac address for this interface
    #
    # Pre: this object exists
    # Post: self.mac has been set with a random mac address
    #
    # Params: octet1-3 - the first three octets in the mac address
    #
    # Return: True if succeeded, False otherwise
    def generateMac(self, octet1 = "02", octet2 = "33", octet3 = "11"):
        # generate the rest of the octets
        octet4 = hex(random.randint(0x00, 0x7f)).lstrip('0x')
        octet5 = hex(random.randint(0x00, 0xff)).lstrip('0x')
        octet6 = hex(random.randint(0x00, 0xff)).lstrip('0x')
        
        # generate and set the mac
        self.mac = octet1 + ":" + octet2 + ":" + octet3 + ":" + str(octet4).rjust(2, '0') + ":" + str(octet5).rjust(2,'0') + ":" + str(octet6).rjust(2,'0') 
        
        return True