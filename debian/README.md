# Debian packaging and building scripts

This directory contains scripts used at the different stages of the
Debian packages build process.  They should be run on a Debian host.

## Builds
The `build-source-package.sh` script builds a Debian source package from
a git repository checkout.  It is to be run in a debian/ branch containing
a debian/ directory.

git-buildpackage is used for the build and should be configured through
the debian/gbp.conf file inside each package.

This script is to be used by the Jenkins builds or in a stand-alone Debian
build-machine.


The `check-deb-rpm-version.sh` script checks that the version of a Debian
package matches the version of the corresponding RPM package.  This is
done through the `build-source-package.sh` script, but  only for the
pscheduler packages.

## Tests
TODO: Use autopkgtests after a package is built.

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

