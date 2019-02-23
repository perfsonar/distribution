#!/bin/sh
# This script will setup a basic Debian installation to have everything needed to 
# build perfSONAR Debian packages.
# It is the normal user script part.

# Get repo/package name
host_repo_path=${host_pwd%/distribution/debian}
export PS_SHARED_REPO=/vagrant/${host_repo_path##*/}

# Adding pS building scripts
cp ${PS_SHARED_REPO}/distribution/debian/build-host-files/pbuilderrc /home/${USER}/.pbuilderrc
cp ${PS_SHARED_REPO}/distribution/debian/build-host-files/scripts/ps-cowbuilder-build /home/${USER}/
chmod +x /home/${USER}/ps-cowbuilder-build

# Make sure result directory in the Vagrant share is existing
[ -d ${PS_SHARED_REPO}/../result ] || mkdir ${PS_SHARED_REPO}/../result
