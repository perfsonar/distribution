#!/usr/bin/env bash
# extglob is needed for the call to tar
shopt -s extglob

# This script will export 3 environment variables: $BUILD_ARCH, $DIST and $RELEASE
# It will get that from the source package archive files: control, gbp.conf and changelog
# We need to look in both debian/ and */debian/ directories because of the difference
# between upstream and Debian native packages

# First get $DIST from gbp.conf
ls -la
echo
`tar -JxOf !(*.orig).tar.xz --wildcards debian/gbp.conf '*/debian/gbp.conf' 2>/dev/null | awk '/DIST=/ {print "export "$3} /^debian-branch/ {print "BRANCH="$3}'`
if [[ "$DIST" = "" ]]; then
    echo "No distribution field (DIST=) found in the source package (in gbp.conf), are you sure it is a Debian package?"
    echo "I quit."
    exit 1
elif [[ $DIST != wheezy && $DIST != jessie && $DIST != stretch ]]; then
    echo "I don't know this distribution: $DIST"
    echo "I quit."
    exit 1
fi

# Then $RELEASE from changelog
`tar -JxOf !(*.orig).tar.xz --wildcards debian/changelog '*/debian/changelog' 2>/dev/null | head -1 | sed 's/\(.*\) (\([0-9.]*\).*) \([A-Za-z0-9.-]*\);.*/export PACKAGE_NAME=\1 VERSION=\2 RELEASE=\3/'`
if [[ "$PACKAGE_NAME" == "iperf3" && "$RELEASE" == "UNRELEASED" ]]; then
    # Special case
    export RELEASE=perfsonar-4.2-snapshot
fi
if [[ "$RELEASE" == "UNRELEASED" ]]; then
    export RELEASE=perfsonar-${BRANCH%.*}-snapshot
fi
if [[ "$RELEASE" == "perfsonar-release" ]]; then
    export RELEASE=perfsonar-${BRANCH%.*}-staging
fi
if [[ "$RELEASE" == "perfsonar-jessie-staging" ]]; then
    export RELEASE=perfsonar-4.1-staging
fi
set -x
if [[ $RELEASE =~ perfsonar-(4.1|4.2|4.3) ]]; then
    export RELEASE=$RELEASE-staging
fi
if [[ ! $RELEASE =~ perfsonar-(4.1|4.2|4.3)-(staging|-snapshot) ]]; then
    echo "I don't know any perfSONAR repository called $RELEASE."
    echo "I cannot work on that package."
    exit 1
fi

# And ARCH from control
if ! tar -JxOf !(*.orig).tar.xz --wildcards debian/control '*/debian/control' 2>/dev/null | grep '^Architecture: ' | grep -qv 'Architecture: all'; then
    export BUILD_ARCH="all"
else
    export BUILD_ARCH="any or some"
fi

# Conclusion
echo "I've found $PACKAGE_NAME version $VERSION to be built for $BUILD_ARCH arch(es) on $DIST and to be released in the $RELEASE repo."

