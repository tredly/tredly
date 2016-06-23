# A class to retrieve data from a tredly host
from subprocess import Popen, PIPE
import re
import builtins

from includes.util import *
from includes.defines import *
from includes.output import *
from objects.nginx.nginxblock import *

class Layer7Proxy:

    # Constructor
    #def __init__(self):
    
    # Action: reload nginx on the host
    #
    # Pre: 
    # Post: nginx configuration files have been reloaded
    #
    # Params: 
    #
    # Return: True if succeeded, False otherwise
    def reload(self):
        # reload nginx
        process = Popen(['service', 'nginx', 'reload'],  stdin=PIPE, stdout=PIPE, stderr=PIPE)
        stdOut, stdErr = process.communicate()

        if (process.returncode != 0):
            e_error("Failed to reload layer 7 proxy")
            return False
        else:
            return True
    
    # Action: add a url to the layer 7 proxy
    #
    # Pre: 
    # Post: the given values have been added as a proxy URL definition within nginx
    #
    # Params: url - the url to add
    #         ip4 - the ip4 address of the container serving this url
    #         maxFileSize - the maximum file size that this URL can receive
    #         servernameFilename - the filename of the server_name file to apply this to
    #         upstreamFilename - the filename of the upstream file to apply this to
    #         errorResponse - whether or not to have the layer 7 proxy respond with its own error page, or to allow the container to serve its own
    #         sslCert - the path to the cert eg ssl/stage/star.tld.com/server.crt
    #         sslKey - the path to the key, eg ssl/stage/star.tld.com/server.key
    #         includes - any extra files to include within this URL
    #
    # Return: True if succeeded, False otherwise
    def registerUrl(self, url, ip4, maxFileSize, websocket, servernameFilename, upstreamFilename, errorResponse, sslCert = None, sslKey = None, includes = None):
        # split the url into its domain and directory parts
        if ('/' in url.rstrip('/')):
            urlDomain = url.split('/', 1)[0]
            urlDirectory = '/' + url.split('/', 1)[1].rstrip('/') + '/'
        else:
            urlDomain = url.rstrip('/')
            urlDirectory = '/'

        # work out which protocol we are redirecting FROM
        if (sslCert is None):
            port = "80"
            protocol = "http"
        else:
            port = "443"
            protocol = "https"
            
        
        # create nginxblocks from each of these files
        servername = NginxBlock(None, None, '/usr/local/etc/nginx/server_name/' + nginxFormatFilename(servernameFilename))
        servername.loadFile()
        upstream = NginxBlock(None, None, '/usr/local/etc/nginx/upstream/' + nginxFormatFilename(upstreamFilename))
        upstream.loadFile()

        #####################################
        # SET UP THE UPSTREAM FILE
        # check if the https upstream block exists
        try:
            upstream.upstream[upstreamFilename]
        except (KeyError, TypeError):
            # not defined, so define it
            upstream.addBlock('upstream', upstreamFilename)
        
        # add the ip address of this container to the upstream block
        upstream.upstream[upstreamFilename].addAttr('server', ip4 + ':' + port)

        # save the upstream file
        if (not upstream.saveFile()):
            return False
        
        #####################################
        # SET UP THE SERVER_NAME FILE

        # check if the server block exists
        try:
            servername.server[0]
        except (KeyError, TypeError):
            # not defined, so define it
            servername.addBlock('server')

        # add ssl specific items
        if (sslCert is not None):
            servername.server[0].attrs['ssl'][0] = "on"
            servername.server[0].attrs['ssl_certificate'][0] = sslCert
            servername.server[0].attrs['ssl_certificate_key'][0] = sslKey
        else:
            # remove the ssl entries
            if ('ssl' in servername.server[0].attrs.keys()):
                del servername.server[0].attrs['ssl']
            if ('ssl_certificate' in servername.server[0].attrs.keys()):
                del servername.server[0].attrs['ssl_certificate']
            if ('ssl_certificate_key' in servername.server[0].attrs.keys()):
                del servername.server[0].attrs['ssl_certificate_key']
        
        # add standard lines
        servername.server[0].attrs['server_name'][0] = urlDomain
        servername.server[0].attrs['listen'][0] = builtins.tredlyCommonConfig.httpProxyIP + ":" + port

        # add the location block
        try:
            servername.server[0].location[urlDirectory]
        except (KeyError, TypeError):
            # not defined, so define it
            servername.server[0].addBlock('location', urlDirectory)
        
        # add any includes that we received
        if (includes is not None):
            for include in includes:
                servername.server[0].location[urlDirectory].addAttr('include', include)
        else:
            # remove the includes
            if ('include' in servername.server[0].location[urlDirectory].attrs.keys()):
                del servername.server[0].location[urlDirectory].attrs['include']
        
        # include websockets if requested, otherwise include http/https include file
        if (websocket):
            servername.server[0].location[urlDirectory].addAttr('include', 'proxy_pass/ws_wss')
        else:
            servername.server[0].location[urlDirectory].addAttr('include', 'proxy_pass/http_https')
        
        # add maxfilesize if requested
        if (maxFileSize is not None):
            servername.server[0].location[urlDirectory].attrs['client_max_body_size'][0] = maxFileSize
        else:
            # check if its already been applied and remove it
            if ('client_max_body_size' in servername.server[0].location[urlDirectory].attrs.keys()):
                del servername.server[0].location[urlDirectory].attrs['client_max_body_size']
        
        # if errorresponse is true then set up tredlys error pages, otherwise the containers page will be used
        if (errorResponse):
            # include 404 page for this URL
            servername.server[0].location[urlDirectory].attrs['error_page'][0] = '404 /tredly_error_docs/404.html'
        else:
            # check if its already been applied and remove it
            if ('error_page' in servername.server[0].location[urlDirectory].attrs.keys()):
                del servername.server[0].location[urlDirectory].attrs['error_page']
                
        
        
        # add the proxy pass attr
        servername.server[0].location[urlDirectory].attrs['proxy_pass'][0] = protocol + "://" + upstreamFilename
        
        ######################
        # Set up error docs location block
        try:
            servername.server[0].location['/tredly_error_docs']
        except (KeyError, TypeError):
            # not defined, so define it
            servername.server[0].addBlock('location', '/tredly_error_docs')
        
        # set/overwrite the values
        servername.server[0].location['/tredly_error_docs'].attrs['alias'][0] = '/usr/local/etc/nginx/tredly_error_docs'
        servername.server[0].location['/tredly_error_docs'].attrs['log_not_found'][0] = 'off'
        servername.server[0].location['/tredly_error_docs'].attrs['access_log'][0] = 'off'
        servername.server[0].location['/tredly_error_docs'].attrs['internal'][0] = None
            
        # save the file
        if (not servername.saveFile()):
            return False
        
        return True
        

    # Action: add an access file to the layer 7 proxy
    #
    # Pre: 
    # Post: an access file has been created
    #
    # Params: file - the path to the file to save this as
    #         whitelist - a list of ip addresses to whitelist in this access file
    #         deny - whether or not to add a deny all rule to the end of this file
    #
    # Return: True if succeeded, False otherwise
    def registerAccessFile(self, file, whitelist, deny = False):
        # create nginxblocks from each of these files
        accessFile = NginxBlock(None, None, file)
        accessFile.loadFile()
        
        # loop over the whitelist and add in the ips to the access file
        if (len(whitelist) > 0):
            for ip4 in whitelist:
                accessFile.addAttr('allow', ip4)
        else:
            accessFile.addAttr('allow', 'all')
        
        # add the deny rule if it was requested
        if (deny):
            accessFile.addAttr('deny', 'all')
        
        return accessFile.saveFile()

    # Action: add a redirect URL to the layer 7 proxy
    #
    # Pre: 
    # Post: the given url has been added to the layer 7 proxy
    #
    # Params: redirectFrom - the URL to redirect from, including protocol. eg https://www.test.com/olddir
    #         redirectTo - the URL to redirect to, including protocol. eg https://www.test.com/newdir
    #         redirectFromSslCert - the SSL Cert to apply to the redirectFrom URL
    #         redirectFromSslKey - the SSL key to apply to the redirectFrom URL
    #
    # Return: True if succeeded, False otherwise
    def registerUrlRedirect(self, redirectFrom, redirectTo, redirectFromSslCert = None, redirectFromSslKey = None):
        
        # split the url into its domain and directory parts
        if ('/' in redirectFrom.rstrip('/')):
            urlDomain = redirectFrom.split('/', 1)[0]
            urlDirectory = '/' + redirectFrom.split('/', 1)[1].rstrip('/') + '/'
        else:
            urlDomain = redirectFrom.rstrip('/')
            urlDirectory = '/'

        # work out which protocol we are redirecting FROM
        if (redirectFromSslCert is None):
            redirectFromProtocol = 'http'
            redirectFromPort = "80"
        else:
            redirectFromProtocol = 'https'
            redirectFromPort = "443"
        
        # split out the redirect to parts
        redirectToProtocol = redirectTo.split('://')[0]
        redirectToDomain = redirectTo.split('://')[1].rstrip('/').split('/',1)[0]
        
        # form the file path - remove trailing slash, and replace dashes with dots
        filePath = "/usr/local/etc/nginx/server_name/" + redirectFromProtocol + '-' + nginxFormatFilename(urlDomain.rstrip('/'))
        
        # create nginxblock object
        servernameRedirect = NginxBlock(None, None, filePath)
        servernameRedirect.loadFile()
        
        # check if the server block exists, and add it if it doesnt
        try:
            servernameRedirect.server[0]
        except (KeyError, TypeError):
            # not defined, so define it
            servernameRedirect.addBlock('server')

        # add attrs
        servernameRedirect.server[0].attrs['server_name'][0] = urlDomain
        servernameRedirect.server[0].attrs['listen'][0] = builtins.tredlyCommonConfig.httpProxyIP + ":" + redirectFromPort
        
        # enable ssl if a cert was presented
        if (redirectFromSslCert is not None):
            servernameRedirect.server[0].attrs['ssl'][0] = "on"
            servernameRedirect.server[0].attrs['ssl_certificate'][0] = redirectFromSslCert
            servernameRedirect.server[0].attrs['ssl_certificate_key'][0] = redirectFromSslKey
        else:
            # remove the ssl entries
            if ('ssl' in servernameRedirect.server[0].attrs.keys()):
                del servernameRedirect.server[0].attrs['ssl']
            if ('ssl_certificate' in servernameRedirect.server[0].attrs.keys()):
                del servernameRedirect.server[0].attrs['ssl_certificate']
            if ('ssl_certificate_key' in servernameRedirect.server[0].attrs.keys()):
                del servernameRedirect.server[0].attrs['ssl_certificate_key']
        
        # add the location block if it doesnt exist
        try:
            servernameRedirect.server[0].location[urlDirectory]
        except (KeyError, TypeError):
            # not defined, so define it
            servernameRedirect.server[0].addBlock('location', urlDirectory)
        
        # add redirect attr
        servernameRedirect.server[0].location[urlDirectory].attrs['return'][0] = "301 " + redirectToProtocol + '://' + redirectToDomain + '$request_uri'
        
        # save the file and return whether it succeeded or not
        return servernameRedirect.saveFile()