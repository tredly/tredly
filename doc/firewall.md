# Firewall Overview
Tredly and the containers running on it have their own separate firewalls - they both use IPFW.

- Tredly's firewall is configured to send traffic to the HTTP/HTTPS Proxy if it receives traffic on tcp ports 80/443.
- Tredly's firewall is configured to forward traffic on particular ports to containers using the layer4 Proxy.
- Tredly's firewall does not contain any rules for the containers running on it.

## Viewing firewall rules
- To view the firewall configuration on Tredly run the command "ipfw list"
- To view the firewall in a container you will need to console into the container and then run "ipfw list"
- Configuring the Container firewall is done using the Tredlyfile
