#!/usr/bin/env bash
# This script will prepare a VM to be ready to install freshly built
# perfSONAR Debian packages.  It should be run as root.
# It can be run subsequently to update an existing setup.

# Get root of shared repo
if [ "${SHARED_REPO_PREFIX}" ]; then
    export PS_SHARED_REPO=${SHARED_REPO_PREFIX}
else
    export PS_SHARED_REPO="${BASH_SOURCE[0]}"
fi
echo -e "\033[1;36mPreparing install environment with scripts from $PS_SHARED_REPO\033[0m"

# Make sure we have some swap enabled, this is not the case with the official Ubuntu images
if [ `free | awk '/^Swap:/ { print $2 }'` == 0 ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
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
DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
#apt-get -y upgrade

# Install some requirements
apt-get install -y gnupg dirmngr
# Install the perfSONAR snapshot repo key
apt-key adv --fetch-keys http://downloads.perfsonar.net/debian/perfsonar-snapshot.gpg.key

# Inform user how to use machine
echo "-------------------------------------------"
echo "perfSONAR install machine ${install_vm_box} is ready!"
echo "You can use it with the following commands:"
echo 
echo "vagrant ssh ${install_vm_hostname}"
echo "./ps-install-test (minor|patch) [PACKAGE]"
echo 
echo "Machine is connected to internal network at"
echo "${install_vm_ip}"
echo "-------------------------------------------"
echo
