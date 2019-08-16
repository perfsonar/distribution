#!/usr/bin/env bash
#
# This script should be run whenever new packages have been published to the repositories
# and the cowbuilder chroot need to be updated.

if [ -z $DISTRO ]; then
    echo $0: usage: Updates a cowbuilder chroot for the given distro, \$DISTRO cannot be empty.
    exit 1
fi
if [ -z $architecture ]; then
    echo $0: usage: Updates a cowbuilder chroot for the given architecture, \$architecture cannot be empty.
    exit 1
fi

echo
echo "Updating cowbuilder environments for ${DISTRO} on ${architecture}"
echo

# We also take care of cleanup the result directory
find /var/cache/pbuilder/result/ -atime +30 -exec rm {} \;

# Looking at stretch images
touch ~/cowbuilder-base-stretch-${architecture}-${DISTRO}-update.lock
sudo -E DIST=stretch cowbuilder --update --basepath /var/cache/pbuilder/base-stretch-${architecture}-${DISTRO}.cow
rm ~/cowbuilder-base-stretch-${architecture}-${DISTRO}-update.lock

# Looking at jessie images
if [[ $architecture =~ (arm64|ppc64el) ]]; then
    echo "There is no more support for $architecture port for Jessie LTS"
else
    touch ~/cowbuilder-base-jessie-${architecture}-${DISTRO}-update.lock
    sudo -E DIST=jessie cowbuilder --update --basepath /var/cache/pbuilder/base-jessie-${architecture}-${DISTRO}.cow
    rm ~/cowbuilder-base-jessie-${architecture}-${DISTRO}-update.lock
fi

