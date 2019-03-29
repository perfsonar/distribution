#!/bin/bash
# extglob is needed for the call to tar
shopt -s extglob

# This script will export 3 environment variables: $BUILD_ARCH, $DIST and $RELEASE
# It will get that from the source package archive files: control, gbp.conf and changelog
# We need to look in both debian/ and */debian/ directories because of the difference
# between upstream and Debian native packages

# First get $DIST from gbp.conf
ls -la
`tar -JxOf !(*.orig).tar.xz --wildcards debian/gbp.conf '*/debian/gbp.conf' 2>/dev/null | awk '/DIST=/ {print "export "$3}'`
if [[ "$DIST" = "" ]]; then
    echo
    echo "No distribution field (DIST=) found in the source package (in gbp.conf), are you sure it is a Debian package?"
    echo "I quit."
    exit 1
elif [[ $DIST != wheezy && $DIST != jessie && $DIST != stretch ]]; then
    echo
    echo "I don't know this distribution: $DIST"
    echo "I quit."
    exit 1
fi

# Then $RELEASE from changelog
`tar -JxOf !(*.orig).tar.xz --wildcards debian/changelog '*/debian/changelog' 2>/dev/null | head -1 | sed 's/.* \([A-Za-z-]*\);.*/export RELEASE=\1/'`
if [ ! "$RELEASE" =~ "perfsonar-(release|(minor|patch)-(staging|snapshot))" ]; then
    echo
    echo "I don't know any perfSONAR repository called $RELEASE."
    echo "I cannot work on that package."
    exit 1
fi

# And ARCH from control
if tar -zxOf !(*.orig).tar.gz --wildcards debian/control '*/debian/control' 2>/dev/null | grep '^Architecture: ' | grep -qv 'Architecture: all'; then
    export BUILD_ARCH="all"
else
    export BUILD_ARCH="any or some"
fi

# Conclusion
echo "I've found a package description for $DIST to be built for $BUILD_ARCH architectures and to be released in the $RELEASE repository."

