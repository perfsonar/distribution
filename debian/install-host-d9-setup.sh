#!/usr/bin/env bash
# This script will augment a basic Debian 9 install to have everything needed to 
# install freshly built perfSONAR Debian packages.  It should be run as root.
# It can be run subsequently to update an existing setup.

# Get repo/package name and build root of shared repo
[ -v host_pwd ] || host_pwd=`pwd`
host_repo_path=${host_pwd%/distribution/debian}
export PS_SHARED_REPO=${SHARED_REPO_PREFIX}${host_repo_path}
echo -e "\033[1;36mPreparing install environment with scripts from $PS_SHARED_REPO\033[0m"

# Add a repository mirror if defined and make it the prefered source
if ! grep -q "$MIRROR" /etc/apt/sources.list; then
    echo -e "\033[1;36mConfiguring Debian repository mirror.\033[0m"
    cp ${PS_SHARED_REPO}/distribution/debian/d9-host-files/sources.list.d/local-debian-mirror.list /etc/apt/sources.list.d/
    sed -i "s|::MIRROR::|${MIRROR}|" /etc/apt/sources.list.d/local-debian-mirror.list
    cat /etc/apt/sources.list >> /etc/apt/sources.list.d/local-debian-mirror.list
    mv /etc/apt/sources.list.d/local-debian-mirror.list /etc/apt/sources.list
    export MIRROR="${MIRROR}"
fi

# Add our local repository
echo -e "\033[1;36mConfiguring local perfSONAR packages repo.\033[0m"
cp ${PS_SHARED_REPO}/distribution/debian/d9-host-files/sources.list.d/local-ps-repo.list /etc/apt/sources.list.d/

# And our local scripts
cd /home/vagrant
cp ${PS_SHARED_REPO}/distribution/debian/d9-host-files/scripts/ps-install-test .
chown vagrant:vagrant ps-install-test
chmod +x ps-install-test

# Refresh APT info
apt-get update

# Install some requirements
apt-get install -y gnupg dirmngr
# Install the perfSONAR snapshot repo key
apt-key adv --fetch-keys http://downloads.perfsonar.net/debian/perfsonar-snapshot.gpg.key

