#!/usr/bin/env bash
# This script will augment a basic Debian 9 install to have everything needed to 
# build perfSONAR Debian packages.  It should be run as root.
# It can be run subsequently to update an existing setup, but then all the
# perfSONAR related chroot will be deleted and recreated anew.

# It accepts the following env vars:
# $MIRROR: A debian repository mirror to use (can be empty)
# $ARCHES: A list of architectures to build packages for (can be empty, then all perfSONAR known architectures will be built)
# $REPO_PREFIX: The repository this script stands in, needed when called from Vagrant because this script is then copied
#                      as a temporary file on the Vagrant host.

# This script is made to be run on standalone developer build machine (Vagrant)
# or on the main Jenkins building host (GÉANT QALAB).

# Get root of shared repo
if [ "${REPO_PREFIX}" ]; then
    export MY_DIR=${REPO_PREFIX}
else
    export MY_DIR=`dirname "${BASH_SOURCE[0]}"`
fi
echo -e "\033[1;36mPreparing build environment with scripts from $MY_DIR\033[0m"

# Add contrib and backport repositories
echo -e "\033[1;36mAdding contrib and backports repositories.\033[0m"
sed -i 's| main$| main contrib|' /etc/apt/sources.list
if ! grep -q "stretch-backports main contrib" /etc/apt/sources.list; then
    echo "deb http://deb.debian.org/debian stretch-backports main contrib" >> /etc/apt/sources.list
fi

# Add a repository mirror if defined and make it the prefered source
if ! grep -q "$MIRROR" /etc/apt/sources.list; then
    echo -e "\033[1;36mConfiguring Debian repository mirror.\033[0m"
    cp ${MY_DIR}/d9-host-files/sources.list.d/local-debian-mirror.list /etc/apt/sources.list.d/
    sed -i "s|::MIRROR::|${MIRROR}|" /etc/apt/sources.list.d/local-debian-mirror.list
    cat /etc/apt/sources.list >> /etc/apt/sources.list.d/local-debian-mirror.list
    mv /etc/apt/sources.list.d/local-debian-mirror.list /etc/apt/sources.list
    export MIRROR="${MIRROR}"
fi

# Do we need to build for some specific architectures only?
[ -n "$ARCHES" ] && export ARCHES="${ARCHES}"

# Install build requirements
apt-get update
apt-get install -y git-buildpackage qemu-user-static vim eatmydata ubuntu-archive-keyring
apt-get -t stretch-backports install -y cowbuilder debootstrap lintian
apt-get autoremove -y

# Setup build environment
mkdir -p /var/cache/pbuilder/hook.d/
echo "# empty file" > /var/cache/pbuilder/hook.d/C99empty
cp ${MY_DIR}/d9-host-files/pbuilderrc.root /root/.pbuilderrc
cp ${MY_DIR}/d9-host-files/scripts/cowbuilder-setup /root/

# Create cowbuilder chroot
for distro in buster bionic stretch; do
    echo -e "\n\033[1;36mSetting chroot for ${distro}.\033[0m\n"
    export DIST="${distro}"
    /root/cowbuilder-setup
    chmod 777 /var/cache/pbuilder/result/$DIST

    # Add our local dev repository
    echo -en "\n\033[1;36mAdding local perfSONAR packages repo to snapshot chroots\033[0m"
    for PSREPO in 4.2 4.3; do
        for ARCH in $ARCHES; do
            if [ -d /var/cache/pbuilder/base-${DIST}-${ARCH}-perfsonar-${PSREPO}-snapshot.cow/etc/apt/sources.list.d/ ]; then
                echo -n " ... ${PSREPO} for ${ARCH}"
                cp ${MY_DIR}/d9-host-files/sources.list.d/local-dev-repo.list /var/cache/pbuilder/base-${DIST}-${ARCH}-perfsonar-${PSREPO}-snapshot.cow/etc/apt/sources.list.d/
                sed -i "s|::DIST::|${DIST}|" /var/cache/pbuilder/base-${DIST}-${ARCH}-perfsonar-${PSREPO}-snapshot.cow/etc/apt/sources.list.d/local-dev-repo.list
            fi
        done
    done
    echo -e ".\033[1;36m Done!\033[0m"
done

