#!/usr/bin/env bash
# This script will augment a basic Debian 9 install to have everything needed to 
# build perfSONAR Debian packages.  It should be run as root.

# Get repo/package name and build root of shared repo
[ -v host_pwd ] || host_pwd=`pwd`
host_repo_path=${host_pwd%/distribution/debian}
export PS_SHARED_REPO=${SHARED_REPO_PREFIX}${host_repo_path}
echo -e "\033[1;36mPreparing build environment with scripts from $PS_SHARED_REPO\033[0m"

# Do we need to use a http_proxy?
[ $http_proxy ] && echo -e "\033[1;36mUsing $http_proxy as http_proxy\033[0m"

# Configure APT
if [ -d ${PS_SHARED_REPO}/distribution/debian/build-host-files/apt.conf.d ]; then
    echo -e "\033[1;36mConfiguring APT with files from build-host-files/apt.conf.d\033[0m"
    cp -R ${PS_SHARED_REPO}/distribution/debian/build-host-files/apt.conf.d/ /etc/apt/apt.conf.d/
fi

# Add contrib and backport repositories
echo -e "\033[1;36mAdding contrib and backports repositories.\033[0m"
sed -i 's| main$| main contrib|' /etc/apt/sources.list
if ! grep -q "stretch-backports main contrib" /etc/apt/sources.list; then
    echo "deb http://deb.debian.org/debian stretch-backports main contrib" >> /etc/apt/sources.list
fi

# Add a repository mirror if defined and make it the prefered source
if ! grep -q "$MIRROR" /etc/apt/sources.list; then
    echo -e "\033[1;36mConfiguring Debian repository mirror.\033[0m"
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
apt-get install -y git-buildpackage qemu-user-static debootstrap eatmydata lintian cowbuilder vim
# If the build.vm is a Jessie box, we would need the following backports:
#apt-get install -y -t stretch-backports debootstrap eatmydata lintian pbuilder
apt-get autoremove -y

# Setup build environment
mkdir -p /var/cache/pbuilder/hook.d/
echo "# empty file" > /var/cache/pbuilder/hook.d/C99empty
cp ${PS_SHARED_REPO}/distribution/debian/build-host-files/pbuilderrc /root/.pbuilderrc
cp ${PS_SHARED_REPO}/distribution/debian/build-host-files/scripts/cowbuilder-setup /root/

# Create cowbuilder chroot
for distro in jessie stretch; do
    export DIST="${distro}"
    /root/cowbuilder-setup
    chmod 777 /var/cache/pbuilder/result/$DIST
done

