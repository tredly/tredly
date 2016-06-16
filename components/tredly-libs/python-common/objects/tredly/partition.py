# A class to represent a tredly partition

class Partition:
    # declare the variables within this class
    name = None;         # name of this partition
    maxHdd = None;       # disk quota
    maxCpu = None;       # maximum cpu usable by this partition
    maxRam = None;       # maximum ram usable by this partition
    

    
    # Constructor
    def __init__(self, name, maxHdd, maxCpu, maxRam):
        self.name = name;
        self.maxHdd = maxHdd;
        self.maxCpu = maxCpu;
        self.maxRam = maxRam;
        # lists
        self.publicIPs = [];    # list of public ips assigned to this partition
        self.ip4Whitelist = []; # list of ip addresses whitelisted for this partition