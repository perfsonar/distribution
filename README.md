# perfSONAR Distribution

This repository contains the components required to build the systems
that make up perfSONAR's distribution network.


## Signing Point

The signing point is where the finished repositories for new version
of perfSONAR are signed and made available to the distribution points
(see below).

### Installation and Setup

TODO: Write this.



## Distribution Point

The distribution point is an Internet-facing system containing
software to mirrors the signing point's distribution tree, an HTTP
server to give access to the distribution tree and an Rsync server to
allow authorized sites to mirror it.

### Installation and Setup

Configure a system as follows:

 * AlmaLinux 8 or AlmaLinux 9 minimal.
 * Set the hostname to the same as its FQDN.
 * Install `git`.
 * Configure a user account that can become the superuser.
 * Do not configure the firewall; the setup process will do it.

As `root`:

 * `cd /tmp`
 * `git clone https://github.com/perfsonar/distribution.git`
 * `./distribution/distribution-point/setup`
 * `rm -rf distribution`
 