#!/bin/bash
#!/bin/bash

if [ -z "$QT_VERSION" ]; then
    echo "Please define the QT_VERSION environment variable as desired"
    exit 1
fi

set -e #quit on error

# Install QT
python3 -m pip install -U pip
python3 -m pip install aqtinstall
python3 -m aqt install --output "$QT_PATH" ${QT_VERSION} linux desktop -m qtwebengine

