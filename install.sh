#!/bin/bash

# Install 'nas' script in /usr/local/sbin for use by root/sudo

SCRIPT_FILE="nas"
TARGET_DIR="/usr/local/sbin"

cp -p ${SCRIPT_FILE} ${TARGET_DIR}
chmod a+rx ${TARGET_DIR}/${SCRIPT_FILE}
