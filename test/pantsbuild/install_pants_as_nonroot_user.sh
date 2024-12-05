#!/bin/bash

set -e

# Check if pants is installed in user's cache dir
if [ ! -d ~/.cache/nce/ ]; then
    exit 1;
fi
