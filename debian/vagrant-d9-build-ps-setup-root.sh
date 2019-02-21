#!/bin/sh
# This script will setup a basic Debian installation to have everything needed to 
# build perfSONAR Debian packages.
# This script should be run as root, a few additional commands need to be run as regular user
# Output is printed in white, so that it stands out from the green output of Vagrant

# Get repo/package name
host_repo_path=${host_pwd%/distribution/debian}
export PS_SHARED_REPO=/vagrant/${host_repo_path##*/}

[ -n $http_proxy ] && echo "\033[1;36mUsing $http_proxy as http_proxy\033[0m"
echo "\033[1;36mPreparing build environment with scripts from $PS_SHARED_REPO\033[0m"

# Configure APT
if [ -d ${PS_SHARED_REPO}/distribution/debian/build-host-files/apt.conf.d ]; then
    echo "\033[1;36mConfiguring APT with files from build-host-files/apt.conf.d\033[0m"
    cp ${PS_SHARED_REPO}/distribution/debian/build-host-files/apt.conf.d/* /etc/apt/apt.conf.d/
fi

# Add contrib and backport repositories
echo "\033[1;36mAdding contrib and backports repositories.\033[0m"
sed -i 's| main$| main contrib|' /etc/apt/sources.list
echo "deb http://deb.debian.org/debian stretch-backports main contrib" >> /etc/apt/sources.list

# Add a repository mirror if defined and make it the prefered source
if [ -n "$MIRROR" ]; then
    echo "\033[1;36mConfiguring Debian repository mirror.\033[0m"
    cp ${PS_SHARED_REPO}/distribution/debian/build-host-files/sources.list.d/local-repo.list /etc/apt/sources.list.d/
    sed -i "s|::MIRROR::|${MIRROR}|" /etc/apt/sources.list.d/local-repo.list
    cat /etc/apt/sources.list >> /etc/apt/sources.list.d/local-repo.list
    mv /etc/apt/sources.list.d/local-repo.list /etc/apt/sources.list
    export MIRROR="${MIRROR}"
fi
# Do we need to build for some specific architectures only?
[ -n "$ARCHES" ] && export ARCHES="${ARCHES}"

# Install build requirements
apt-get update
apt-get install -y git-buildpackage qemu-user-static debootstrap eatmydata lintian cowbuilder
# If the build.vm is a Jessie box, we would need the following backports:
#apt-get install -y -t stretch-backports debootstrap eatmydata lintian pbuilder
apt-get autoremove -y

# Setup build environment
mkdir /var/cache/pbuilder/hook.d/
cp ${PS_SHARED_REPO}/distribution/debian/build-host-files/pbuilderrc /root/.pbuilderrc
cp ${PS_SHARED_REPO}/distribution/debian/build-host-files/pbuilder-hook.d/* /var/cache/pbuilder/hook.d/
cp ${PS_SHARED_REPO}/distribution/debian/build-host-files/scripts/cowbuilder-setup /root/
chmod +x /root/cowbuilder-setup
chmod +x /var/cache/pbuilder/hook.d/*

# Create cowbuilder chroot
for distro in jessie stretch; do
    export DIST="${distro}"
    /root/cowbuilder-setup
done

