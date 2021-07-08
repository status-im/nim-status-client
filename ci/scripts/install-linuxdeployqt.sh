#!/bin/bash
# Download and install linuxdeployqt
# Companion script for the Docker image a12e/docker-qt
# Aurélien Brooke - License: MIT

set -e #quit on error 

if [ -z "$LINUXDEPLOYQT_VERSION" ]; then
    echo "Please define the LINUXDEPLOYQT_VERSION environment variable as desired"
    exit 1
fi

mkdir -p /usr/local/bin
curl -Lo/usr/local/bin/linuxdeployqt "https://github.com/probonopd/linuxdeployqt/releases/download/$LINUXDEPLOYQT_VERSION/linuxdeployqt-$LINUXDEPLOYQT_VERSION-x86_64.AppImage"
chmod a+x /usr/local/bin/linuxdeployqt
