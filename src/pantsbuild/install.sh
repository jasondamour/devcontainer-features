#!/bin/sh
set -e

PANTS_VERSION=${VERSION:-"latest"}
USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"


# Bring in ID, ID_LIKE, VERSION_ID, VERSION_CODENAME
. /etc/os-release

# Get an adjusted ID independent of distro variants
MAJOR_VERSION_ID=$(echo ${VERSION_ID} | cut -d . -f 1)
if [ "${ID}" = "debian" ] || [ "${ID_LIKE}" = "debian" ]; then
    ADJUSTED_ID="debian"
elif [[ "${ID}" = "rhel" || "${ID}" = "fedora" || "${ID}" = "mariner" || "${ID_LIKE}" = *"rhel"* || "${ID_LIKE}" = *"fedora"* || "${ID_LIKE}" = *"mariner"* ]]; then
    ADJUSTED_ID="rhel"
    if [[ "${ID}" = "rhel" ]] || [[ "${ID}" = *"alma"* ]] || [[ "${ID}" = *"rocky"* ]]; then
        VERSION_CODENAME="rhel${MAJOR_VERSION_ID}"
    else
        VERSION_CODENAME="${ID}${MAJOR_VERSION_ID}"
    fi
else
    echo "Linux distro ${ID} not supported."
    exit 1
fi

# Setup INSTALL_CMD & PKG_MGR_CMD
if type apt-get > /dev/null 2>&1; then
    PKG_MGR_CMD=apt-get
    INSTALL_CMD="${PKG_MGR_CMD} -y install --no-install-recommends"
elif type microdnf > /dev/null 2>&1; then
    PKG_MGR_CMD=microdnf
    INSTALL_CMD="${PKG_MGR_CMD} ${INSTALL_CMD_ADDL_REPOS} -y install --refresh --best --nodocs --noplugins --setopt=install_weak_deps=0"
elif type dnf > /dev/null 2>&1; then
    PKG_MGR_CMD=dnf
    INSTALL_CMD="${PKG_MGR_CMD} ${INSTALL_CMD_ADDL_REPOS} -y install --refresh --best --nodocs --noplugins --setopt=install_weak_deps=0"
else
    PKG_MGR_CMD=yum
    INSTALL_CMD="${PKG_MGR_CMD} ${INSTALL_CMD_ADDL_REPOS} -y install --noplugins --setopt=install_weak_deps=0"
fi

pkg_mgr_update() {
    case $ADJUSTED_ID in
        debian)
            if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
                echo "Running apt-get update..."
                ${PKG_MGR_CMD} update -y
            fi
            ;;
        rhel)
            if [ ${PKG_MGR_CMD} = "microdnf" ]; then
                if [ "$(ls /var/cache/yum/* 2>/dev/null | wc -l)" = 0 ]; then
                    echo "Running ${PKG_MGR_CMD} makecache ..."
                    ${PKG_MGR_CMD} makecache
                fi
            else
                if [ "$(ls /var/cache/${PKG_MGR_CMD}/* 2>/dev/null | wc -l)" = 0 ]; then
                    echo "Running ${PKG_MGR_CMD} check-update ..."
                    set +e
                    ${PKG_MGR_CMD} check-update
                    rc=$?
                    if [ $rc != 0 ] && [ $rc != 100 ]; then
                        exit 1
                    fi
                    set -e
                fi
            fi
            ;;
    esac
}

# Checks if packages are installed and installs them if not
check_packages() {
    case ${ADJUSTED_ID} in
        debian)
            if ! dpkg -s "$@" > /dev/null 2>&1; then
                pkg_mgr_update
                ${INSTALL_CMD} "$@"
            fi
            ;;
        rhel)
            if ! rpm -q "$@" > /dev/null 2>&1; then
                pkg_mgr_update
                ${INSTALL_CMD} "$@"
            fi
            ;;
    esac
}

echo "Installing dependencies..."
check_packages ca-certificates
check_packages curl


curl --proto '=https' --tlsv1.2 -fsSL https://static.pantsbuild.org/setup/get-pants.sh | bash -s -- --bin-dir /usr/bin

if [ "$PANTS_VERSION" != "none" ]; then
    mkdir -p tmp/
    chown -hR ${_REMOTE_USER} tmp/

    # If version is explicitly set, write it to a pants.toml file
    if [ "$PANTS_VERSION" != "latest" ]; then
        echo "[GLOBAL]" > tmp/pants.toml
        echo "pants_version = \"$PANTS_VERSION\"" >> tmp/pants.toml
    fi

    su ${USERNAME} -c "cd tmp && echo Y | pants --version"
    rm -rf tmp/
fi
