#!/usr/local/bin/bash

tredly create partition tests
mkdir -p /tredly/ptn/tests/data/sslCerts/selfsigned
cd /tredly/ptn/tests/data/sslCerts/selfsigned

openssl genrsa -des3 -out server.key -passout pass:tredly 2048
openssl req -new -key server.key -out server.csr -passin pass:tredly -subj "/C=AU/ST=QLD/L=Brisbane/O=Tredly/OU=IT/CN=tredly.com"
cp server.key server.key.org
openssl rsa -in server.key.org -out server.key -passin pass:tredly
openssl x509 -req -days 3650 -in server.csr -signkey server.key -out server.crt -passin pass:tredly
