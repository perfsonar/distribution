#!/usr/bin/env bash
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

# Build the package for the selected architecture and don't remove any other package from repo (default jenkins-debian-glue behavior)
#export SKIP_MISSING_BINARY_REMOVAL=yes

# Update the cowbuilder environement to make sure we use the latest packages to solve dependencies
sudo cowbuilder --update --basepath /var/cache/pbuilder/base-${DIST}-${architecture}-${RELEASE}.cow

# We use the perfSONAR Debian Archive Automatic Signing Key to sign both repositories
export KEY_ID="8968F5F6"

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

sudo -E DIST=${DIST} ARCH=${architecture} cowbuilder --build ./${sourcefile} --basepath /var/cache/pbuilder/base-${DIST}-${architecture}-${RELEASE}.cow --buildresult /var/cache/pbuilder/result/${DIST} --debbuildopts "-sa -b"
[ $? -eq 0 ] || exit 1

# Add resulting packages to local repository
reprepro -b /srv/repository include ${RELEASE} /var/cache/pbuilder/result/${DIST}/${SOURCE_PACKAGE}_*${newest_version}_${architecture}.changes

# Run Lintian on built package
lintian ${PKG}*.changes
