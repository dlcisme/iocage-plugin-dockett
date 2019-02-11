#!/bin/bash

_DOCKETT_USER="dockett"
_DOCKETT_PASSWORD="dockett"
_DATA_LOCATION="/app-data/dockett/"

echo $_DOCKETT_PASSWORD | pw user add -n $_DOCKETT_USER -s /bin/sh -m -h 0 -c "User for Dockett"

# create the data location
mkdir -p $_DATA_LOCATION

# make "dockett" the owner of the data location
chown -R $_DOCKETT_USER:$_DOCKETT_USER $_DATA_LOCATION