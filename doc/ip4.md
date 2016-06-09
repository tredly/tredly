# IPv4

## Reserved Private Addresses
Tredly is intended to be used in conjunction with a /16 private container subnet, however the subnet can be changed to any number of configurations . Typically this will be a 10.x.y.z/16 subnet.

The end of an IP subnet contains reserved addresses for use by Tredly containers. For example in the default 10.99.0.0/16 subnet, the following ip addresses are reserved:
* 10.99.255.254 - Tredly Host Interface
* 10.99.255.253 - Layer 7 Proxy Container
* 10.99.255.252 - API Web interface Container
* 10.99.255.251 - Command Center Container
* 10.99.255.250 - Private DNS Container
