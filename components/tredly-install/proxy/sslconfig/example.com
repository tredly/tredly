# The following is an example of a SSL certificate configuration for the Tredly Layer 7 proxy
# Please uncomment the below to use this as your template

#ssl on;
#ssl_certificate ssl/example.com/server.crt;
#ssl_certificate_key ssl/example.com/server.key;
