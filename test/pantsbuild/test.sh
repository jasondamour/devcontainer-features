#!/bin/bash

set -e

# EXPECTED_VERSION is optional. If not set, the script should succeed if none of the other conditions exit.
EXPECTED_VERSION=${1}
NONROOT_SUDO_PASSWORD=${2}

# SETUP
if ! command -v expect &> /dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    export TZ=Etc/UTC

    if command -v sudo &> /dev/null; then
        sudo apt-get -qq update 
        sudo apt-get -qq install -y expect 
    else
        apt-get -qq update
        apt-get -qq install -y expect
    fi
fi


# If version is explicitly set, write it to a pants.toml file
if [ "$EXPECTED_VERSION" != "latest" ]; then
    echo "[GLOBAL]" > pants.toml
    echo "pants_version = \"$EXPECTED_VERSION\"" >> pants.toml
fi

expect <<END_EXPECT
    spawn pants --version
    expect {
        -re "Would you like to configure .*" {
            send "Y"
        }
        ${EXPECTED_VERSION} {
            send_user "\n\[SUCCESS\] Pants version matches expected version: $EXPECTED_VERSION\n"
            exit 0
        }
        timeout {
            send_user "\n\[ERROR\] Timed out waiting for Pants version\n"
            exit 1
        }
    }
END_EXPECT
