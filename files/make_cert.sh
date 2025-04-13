#!/bin/bash
# Navigate to home directory
cd ~

# Remove the ssl directory if it exists, and create a new one
rm -rf ssl
mkdir ssl
cd ssl

# Generate a 4096-bit RSA private key with AES256 encryption for the CA
openssl genrsa -aes256 -out privkey_cert.key 4096
# Generate a certificate signing request (CSR) for the CA
openssl req -new -key privkey_cert.key -out cacert.csr
# Generate a self-signed certificate (cacert.pem) for the CA, valid for 10 years
openssl x509 -req -in cacert.csr -signkey privkey_cert.key -days 3650 -extensions v3_ca -out cacert.pem

# Generate another 4096-bit RSA private key with AES256 encryption for the server
openssl genrsa -aes256 -out privkey_withpasswd.key 4096
# Generate a CSR for the server
openssl req -new -key privkey_withpasswd.key -out server.csr

# Remove the passphrase from the server private key
openssl rsa -in privkey_withpasswd.key -out server.key

# Generate a server certificate (server.crt) using the CA certificate, valid for 2 years
openssl x509 -req -in server.csr -CA cacert.pem -CAkey privkey_cert.key -CAcreateserial -extfile ../subjectnames.txt -days 730 -out server.crt

# Move back to the parent directory and move the ssl directory to the home directory
cd ..
mv -f ./ssl ~/
