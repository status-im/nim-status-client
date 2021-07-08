#!/bin/bash
# Download and compile OpenSSL for Linux, and install it in the /usr/local/ssl directory prefix
# Companion script for the Docker image a12e/docker-qt
# Aurélien Brooke - License: MIT

if [ -z "$OPENSSL_PREFIX" ]; then
    echo "Please define the OPENSSL_PREFIX environment variable as desired."
    exit 1
fi

if [ -z "$OPENSSL_VERSION" ]; then
    echo "Please define the OPENSSL_VERSION environment variable as desired."
    exit 1
fi

set -e #quit on error

cd ~/
curl -Lo openssl-${OPENSSL_VERSION}.tar.gz https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
tar xvf openssl-${OPENSSL_VERSION}.tar.gz
rm -fv openssl-${OPENSSL_VERSION}.tar.gz
mv openssl-${OPENSSL_VERSION}/ openssl/
cd openssl/

./config --prefix=${OPENSSL_PREFIX} --openssldir=${OPENSSL_PREFIX} shared zlib

make -j$(nproc)
make -j$(nproc) install

echo ${OPENSSL_PREFIX}/lib > /etc/ld.so.conf.d/openssl-${OPENSSL_VERSION}.conf
ldconfig -v
