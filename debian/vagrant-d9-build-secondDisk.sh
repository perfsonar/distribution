#!/bin/sh
# This script add a second disk to keep all the pbuilder chroot

echo "\033[1;36mCreating new /var/cache/pbuilder partition on second disk /dev/sdb.\033[0m"

# Create a single partition on the new disk
sfdisk /dev/sdb << EOF
,,L
EOF

# Create filesystem and mount the new partition
mkfs.ext4 /dev/sdb1
mkdir /var/cache/pbuilder
echo "/dev/sdb1       /var/cache/pbuilder   ext4 rw,relatime 0 0" >> /etc/fstab 
mount -a

