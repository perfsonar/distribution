# Distribution Receiver

This directory contains a set of programs for maintaining a set of
directories called _storage areas_ and allowing remote SSH clients
holding a private key generated specifically for each directory to
synchronize their contents.


## Installation

1.  Create a non-root account to serve as the receiver.

1.  Identify a location on your system where the account has read and
write access and sufficient space to hold whatever you plan to
synchronize.  (Home directory is fine and customary.)

1.  Unpack the contents of this directory into that location.

1.  In that directory, run `make`.


## Setup

For each storage area, do the following:

1.  Run `./bin/add storage-area-name`, where _storage-area-name_ is a
name for the storage area.  This is a valid filename and may not
contain slashes or be `rrsync`.

1.  When prompted, set an appropriate password for that area's SSH key
(or none if desired).

Note that this process will create a directory for the storage area
and a SSH private/public key pair.  A command-restricted version of
the public key will be added to `~/.ssh/authorized_keys`.  If any of
the above already exist, the step will be skipped.


## Synchronizing to a Directory

1.  Copy the private key for the storage area you will be synchronizing
(e.g., `keys/somearea`) to the remote host.

1.  `rsync -e "ssh -i /path/to/private/key" /path/to/local/files/
user@remotehost:`.  Note that the colon at the end of the last
argument must be present.


## Maintenance

To remove a storage, its key and entry from `~/.ssh/authorized_keys`,
run `./bin/remove storage-area-name`, where _storage-area-name_ is the
name of the storage area to be removed.


## Removal

To remove everything and set the directory back to its pristine state,
run `make distclean`.
