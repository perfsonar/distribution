#!/usr/bin/env bash
#
# This script should be run whenever new packages have been published to the repositories
# and the cowbuilder chroot need to be updated.

if [ -z $distro ]; then
    echo $0: usage: Updates a cowbuilder chroot for the given distro, \$distro cannot be empty.
    exit 1
fi

for arch in amd64 arm64 armel armhf i386 ppc64el; do
    echo
    echo "Updating cowbuilder environments for ${distro} on ${arch}"
    echo
    touch ~/cowbuilder-base-stretch-${arch}-${distro}-update.lock
    sudo cowbuilder --update --basepath /var/cache/pbuilder/base-stretch-${arch}-${distro}.cow
    rm ~/cowbuilder-base-stretch-${arch}-${distro}-update.lock
    if [[ $arch =~ (arm64|ppc64el) ]]; then
        echo "There is no more support for $arch port for Jessie LTS"
    else
        touch ~/cowbuilder-base-jessie-${arch}-${distro}-update.lock
        sudo cowbuilder --update --basepath /var/cache/pbuilder/base-jessie-${arch}-${distro}.cow
        rm ~/cowbuilder-base-jessie-${arch}-${distro}-update.lock
    fi
done

