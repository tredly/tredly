import sys


import os.path

from objects.nginx.nginxblock import *


servername = NginxBlock(None, None, '/usr/local/etc/nginx/server_name/https-www.stage.vuid.com')
servername.loadFile()



try:
    servername.server[0]
except (KeyError, TypeError):
    # not defined, so define it
    servername.addBlock('server')


# add standard attrs for SSL
servername.server[0].addAttr('ssl', 'on')
print(servername.toString())

servername.saveFile()
exit(0)