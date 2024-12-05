#!/bin/bash

set -e

# Install expect if not already installed
if ! command -v expect &> /dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    export TZ=Etc/UTC
    apt-get update
    apt-get install -y expect
fi

expect -c '
    spawn pants --version
    expect {
        "installing" { exit 1 }
        eof
    }
'
