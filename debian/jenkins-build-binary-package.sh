#!/bin/bash
# This script build a Debian binary package from a source package
# It is meant to be run from Jenkins

# Get $BUILD_ARCH, $DIST and $RELEASE from the content of the source package
. ~/distribution/debian/check-release-repo.sh
[ $? -eq 0 ] || exit 1

if [[ $architecture != amd64 && "$BUILD_ARCH" == "all" ]]; then
    echo "I skip building binary independent package on $architecture"
    exit 0
fi

# Check if repo exist, should be ok from check-release-repo.sh but we never know…
echo -n "I'll build binary packages in ${DIST}-$architecture "
reprepro -b /srv/repository check ${RELEASE} 2>/dev/null
if [ $? -ne 0 ]; then
    echo "but"
    echo "${RELEASE} repository doesn't seem to exist in /srv/repository"
    echo "I'll stop here."
    exit 0
fi
echo "and I'll store both source and binary packages into ${RELEASE}."
echo

# We use the jenkins-debian-glue key to sign both repositories
export KEY_ID="8968F5F6"

# pbuilder configuration file to define our repo sources where we get the build dependencies
#export PBUILDER_CONFIG=mypbuilderrc
#echo "
#MIRROR=\"http://ftp.task.gda.pl/debian/\"
#OTHERMIRROR=\"deb http://ps-deb-repo.qalab.geant.net/repository ${RELEASE} main|deb http://ftp.task.gda.pl/debian ${DIST}-backports main\"
#DISTRIBUTION=${DIST}
#BINDMOUNTS="/var/cache/pbuilder/result/$DIST"
#" > $PBUILDER_CONFIG
#export distribution=$DIST

# Build the package for the selected architecture and don't remove any other package from repo (default jenkins-debian-glue behavior)
#export SKIP_MISSING_BINARY_REMOVAL=yes

# Look for more recent package to build
for file in *.dsc ; do
    SOURCE_PACKAGE="$(awk '/^Source: / {print $2}' $file)"
    p="$(basename $file .dsc)"
    if [ "$p" = '*' ] ; then
        echo "No source package found"
        exit 1
    fi
    cur_version="${p#*_}"
    if [ -z "${newest_version}" ] || dpkg --compare-versions "${cur_version}" gt "${newest_version}" ; then
        newest_version="${cur_version}"
    fi
done
sourcefile="${SOURCE_PACKAGE}"_*"${newest_version}".dsc
echo "*** Using $sourcefile (version: ${newest_version})"

# Skip autopkgtest for now, they are too slow
# TODO: How to run autopkg without Debian Jenkins Glue?
#export ADT=skip

if [[ $parent == i2util-debian-source ]]; then
    # Force a binary only build to avoid issue with sources being changed by bootstrap.sh (specific to i2util binary build)
    # Should this be done for all packages or should the i2util build be changed?
    sudo -E DIST=${DIST} ARCH=${architecture} cowbuilder --build ./${sourcefile} --basepath /var/cache/pbuilder/base-${DIST}-${architecture}-${RELEASE}.cow --buildresult /var/cache/pbuilder/result/${DIST} --debbuildopts -B
else
    sudo -E DIST=${DIST} ARCH=${architecture} cowbuilder --build ./${sourcefile} --basepath /var/cache/pbuilder/base-${DIST}-${architecture}-${RELEASE}.cow --buildresult /var/cache/pbuilder/result/${DIST} --debbuildopts -sa
fi

# Add resulting packages to local repository
reprepro -b /srv/repository include ${RELEASE} /var/cache/pbuilder/result/${DIST}/${SOURCE_PACKAGE}_*${newest_version}_${architecture}.changes

#/usr/bin/build-and-provide-package
[ $? -eq 0 ] || exit 1

# Create lintian report in junit format, if jenkins-debian-glue is installed
if [ -x /usr/bin/lintian-junit-report ]; then
    /usr/bin/lintian-junit-report ${PKG}*.changes > lintian.xml
else
    lintian ${LINTIAN_ARGS} ${PKG}*.changes
fi
