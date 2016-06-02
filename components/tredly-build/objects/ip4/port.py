# A class to represent an IP port

class Port:
    # Constructor
    def __init__(self, protocol, direction, number):
        self.protocol = protocol;
        self.direction = direction;
        self.number = number;
