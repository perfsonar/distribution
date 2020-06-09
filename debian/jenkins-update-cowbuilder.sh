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

# Loop on all distro we have a build environement
for distro in buster bionic stretch; do
    touch ~/cowbuilder-base-${distro}-${architecture}-${DISTRO}-update.lock
    sudo -E DIST=${distro} cowbuilder --update --basepath /var/cache/pbuilder/base-${distro}-${architecture}-${DISTRO}.cow
    rm ~/cowbuilder-base-${distro}-${architecture}-${DISTRO}-update.lock
done

