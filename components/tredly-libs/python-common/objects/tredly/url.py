# A class to represent a tredlyfile url

from objects.tredly.urlredirect import *;

class URL:
    # lists
    urlRedirects = [];    # list of URLRedirects for this url

    # Constructor
    def __init__(self, url):
        self.url = url;
        self.cert = None;     # certificate that relates to this url if it is HTTPS
        self.websocket = False;      # whether this url responds to websockets
        self.maxFileSize = None;     # maximum upload size this url accepts
