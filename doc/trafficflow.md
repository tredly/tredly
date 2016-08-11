# Traffic Flow
Tredly is designed to leverage a single public IP so you can run thousands of containers without the need for a large public subnet.

## How traffic flows in Tredly is pretty simple:

- Traffic hits the external IP(s) of your Tredly server.
    - If the traffic is for tcp port 80/443 (HTTP/HTTPS) the traffic is sent to the Layer 7‚ Proxy.
    - If the traffic is for any other tcp or udp ports and a container has requested layer4proxy then it is sent to the layer 4 proxy.

### What happens next:

- Containers servicing a URL:
    - When you create a container that is servicing a URL, the Proxy is informed‚ about this URL and the IP of the container.
    - When the Proxy receives traffic for the URL it forwards the traffic to the container.
    - Your container needs to be configured to allow this traffic in (tcpInPorts, udpInPorts)
    - Your service within the container needs to be configured to accept traffic for that URL.
- Containers using Layer4 Proxy
    - Layer4 Proxy is informed‚ about the Container and values in tcpInPort udpInPorts (Tredlyfile)
    - When Layer4 Proxy receives traffic on those ports it is sent to the container
    - Your service within the container‚ needs to be configured to accept traffic for those ports.
