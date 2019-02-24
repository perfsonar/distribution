# Debian packaging and building scripts

This directory contains scripts used at the different stages of the
Debian packages build process.  They are meant to be run on a Debian host or
from a host supporting VirtualBox Vagrant hosts.

## Quickstart

From this directory, just run (replace `repository-name` with the actual repo
you want to build):

```bash
vagrant up
vagrant ssh
./ps-cowbuilder-build $PS_REPO
exit
```

The resulting packages will be in a /results/ directory at the same level as
the git repository you're building.

## Vagrant VM
The Debian packages build process is using Vagrant to allow for easier builds.
The Vagrantfile we provide is relying on a local VirtualBox host and is using
the regular Debian Box you can find at https://app.vagrantup.com/debian/

### d9-build-ps VM
This machine is built out of a regular Debian Stretch box.  2 provisioning
scripts are setting up the build environment.  Our full Debian build environement
is using a cowbuilder/pbuilder subsytem to isolate the builds in a dedicated and
clean chroot.

The machine is making use of 2 environment variables:

- `PS_DEB_ARCHES` list the architectures for which packages will be built, an empty
    list will build all the supported arches.
- `PS_DEB_MIRROR` can contain the base URL of a Debian repository mirror you want
    to use (i.e. close to you), if not set the repository used will be the default
    one setup in the Debian box (which should be fine most of the time)

If you want to change those variables, it is recommended to do so in your own local
`~/.vagrant.d/Vagrantfile` (see https://www.vagrantup.com/docs/vagrantfile/#load-order-and-merging )

Additionnaly, all files from the `build-host-files/apt.conf.d/` directory will be
copied to the d9-build-ps VM so that you can make a dedicated APT setup if you need.
That can be useful if you want to use a proxy for example.

### d9-install-ps VM
This machine will be setup to test a newly built Debian package can be installed
cleanly with all dependencies solved.

## Scripts
The Vagrant setup described hereabove is using the different follwoing scripts.

### Full Builds
Full package builds are creating first the source package and then a number of
architecture dependant binary packages.  A full build can be launched with the
`ps-cowbuild-build` script.

This script can use some options:

- `-b` the branch that you want to build
- `-t` the tag that you want to build (release build)
- `-s` to build a source package only

### Source Builds
The `build-source-package.sh` script builds a Debian source package from
a git repository checkout.  It is to be run in a branch containing a debian/
directory.

git-buildpackage is used for the build and should be configured through
the debian/gbp.conf file inside each package.

This script is to be used by the Jenkins builds or in a stand-alone Debian
build-machine (like the one provided by the Vagrant setup hereabove)


The `check-deb-rpm-version.sh` script checks that the version of a Debian
package matches the version of the corresponding RPM package.  The
`build-source-package.sh` script is calling it for each pscheduler package.

## Tests
TODO: We should make use of autopkgtests after a package is built.

## Release
The `make-release.sh` script is to be used when releasing a Debian package.
It must be run in the debian/version branch you want to use for the release. When
you run it, it will:
 - check the version of the package in the debian/changelog
 - verify a corresponding git tag exist in the upstream branch
 - refresh the quilt patches
 - updates the distribution submodule to latest commit
 - updates the debian changelog to the new release
 - git commit and tag on the debian branch

Some parameters and options can be passed to this script, check the script
for more information.

