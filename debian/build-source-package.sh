#!/usr/bin/env bash
# This script builds a perfSONAR Debian source package from a git repository checkout.
# It uses git-buildpackage and its configuration for the package in debian/gbp.conf
# It is made to work with Jenkins, for that purpose the git repository need to be checked out
# in a sub-directory of the Jenkins workspace, per convention we call this sub-directory 'source'.
# The resulting artefacts will be at the root level of the workspace.
#
# It also uses the following environment variables (or Jenkins parameters)
#   tag: the git tag to build from (ex: 4.0-2.rc1-1)
#   branch: the git branch to build from (ex: debian/jessie)
# If none of these variables/parameters are set, then the script looks for the branch to build
# in the debian/gbp.conf configuration file.

# Configuration
SRC_DIR='source'
GIT_BUILDING_REPO='distribution'
BASE_DIR=$(pwd)
MY_DIR=$(dirname "$0")

# Go into the directory where we checked out source
cd ${SRC_DIR}

# extglob is needed to cleanup pscheduler repo and save disk space
shopt -s extglob
# Kludge detection, this need to be done in the correct branch!
# This means that the Jenkins job must be configured to checkout the exact branch that we will be building
if [ ! -f debian/gbp.conf ]; then
    # No debian directory, we're probably building pscheduler or a minor-package
    if [ -d "${package}" ]; then
        # It seems we're right, now, are we at the correct location?
        cd ${package}
        if ! [ -d debian ]; then
            cd */debian
            pscheduler_dir_level=".."
        else
            pscheduler_dir_level="."
        fi
        # We take the package name from the changelog entry, as this is not necessarily the same as the directory name...
        cd ${pscheduler_dir_level}
        package_dir=$package
        package=`awk 'NR==1 {print $1}' debian/changelog`
    else
        echo -e "\nI don't recognise what you want me to build, pscheduler/minor-packages builds need to have the env variable 'package' set."
        echo -e "package=${package} and I don't see a directory with this name.  I stop.\n"
        ls -al
        exit 1
    fi
fi

# Get the current branch and commit, before making any change
CURRENT_BRANCH=`git rev-parse --abbrev-ref HEAD`
CURRENT_COMMIT=`git rev-parse --short HEAD`

# Check the tag parameter, it has precedence over the branch parameter
DEBIAN_TAG=$tag
[ -n $DEBIAN_TAG ] && git checkout ${DEBIAN_TAG}

# We don't want to package any submodule
git submodule deinit -f .

# Get upstream branch from gbp.conf and making it a local branch so we can merge and build tarball from it
UPSTREAM_BRANCH=`awk -F '=' '/upstream-branch/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' debian/gbp.conf`
PKG=`awk 'NR==1 {print $1}' debian/changelog`
git branch ${UPSTREAM_BRANCH} origin/${UPSTREAM_BRANCH}
UPSTREAM_COMMIT=`git rev-parse --short -b ${UPSTREAM_BRANCH}`

# Our default gbp options
GBP_OPTS="-nc --git-force-create --git-ignore-new --git-ignore-branch -S -us -uc --git-verbose --git-builder=/bin/true --git-cleaner=/bin/true --git-export-dir="

# Special repositories/packages needs
case "${PKG}" in
    "maddash")
        # MaDDash has a submodule we want to package!
        GBP_OPTS=$GBP_OPTS" --git-submodules"
        git submodule update --init maddash-server/madalert
        ;;
esac

# We differentiate snapshot and release builds
if [ -z $DEBIAN_TAG ]; then
    # If we don't have a tag, we take the source from the current branch and merge upstream in it so we have the latest changes
    echo -e "\nBuilding snapshot package of ${PKG} from ${CURRENT_BRANCH} (${CURRENT_COMMIT}) merged with ${UPSTREAM_BRANCH} (${UPSTREAM_COMMIT}).\n"
    git merge -m "Merging upstream ${UPSTREAM_BRANCH}" ${UPSTREAM_BRANCH}
    # We set the author of the Debian Changelog, only for snapshot builds (this doesn't seem to be used by gbp dch :(
    export DEBEMAIL="perfSONAR developers <debian@perfsonar.net>"
    # And we generate the changelog ourselves, with a version number suitable for an upstream snapshot
    timestamp=`date +%Y%m%d%H%M%S`
    current_version=`dpkg-parsechangelog | sed -n 's/Version: \(.*\)$/\1/p'`
    # The new version must be below the final (without timestamp), hence using the ~
    if grep -q '(native)' debian/source/format ; then
        # Native package don't have a release number
        new_version=${current_version}~${timestamp}
    else
        new_version=${current_version%-*}~${timestamp}-${current_version##*-}
    fi
    dch -b --distribution=UNRELEASED --newversion=${new_version} -- 'SNAPSHOT autobuild for '${current_version}' via Jenkins'
    GBP_OPTS="$GBP_OPTS --git-upstream-tree=HEAD"
    dpkgsign="-k8968F5F6"
else
    # If we have a tag, we take the source from the git tag
    echo -e "\nBuilding release package of ${PKG} from ${DEBIAN_TAG}.\n"
    # We build the upstream tag from the Debian tag by, see https://github.com/perfsonar/project/wiki/Versioning :
    # - adding a leading "v"
    # - removing the leading debian/distro prefix
    # - removing the ending -1 debian-version field
    # - transforming any ~x.b1 beta relnum to -x.b1
    UPSTREAM_TAG=v${DEBIAN_TAG##*\/}
    UPSTREAM_TAG=${UPSTREAM_TAG%-*}
    UPSTREAM_TAG=${UPSTREAM_TAG/~/-}
    GBP_OPTS="$GBP_OPTS --git-upstream-tree=$UPSTREAM_TAG"
    # We don't sign the release package as we don't have the packager's key
    dpkgsign="-us -uc"
fi

# We package the upstream sources (tarball) from git
if [ "$pscheduler_dir_level" ]; then
    # Directly calling git archive if pscheduler, because we have multiple packages inside a single repo
    # Native packages don't have upstream version, we don't need to create the upstream tarball
    if ! grep -q '(native)' debian/source/format ; then
        # Backward kludge...
        cd ../$pscheduler_dir_level
        # We first check that the RPM version matches the DEB version (but not for minor-packages)
        if ! git remote -v show | grep minor-packages ; then
            if ! ${MY_DIR}/check-deb-rpm-version.sh ${package_dir} ; then
                pwd
                exit 1
            fi
        fi
        # And forward kludge again
        cd ${package_dir}
        if ! [ -d debian ]; then
            cd */debian/..
        fi
        # We remove the -pkgrel suffix
        upstream_version=`dpkg-parsechangelog | sed -n 's/Version: \(.*\)-[^-]*$/\1/p'`
        if ! [ -e ../${package}_${upstream_version}.orig.tar.gz ] &&
            ! [ -e ../${package}_${upstream_version}.orig.tar.xz ] &&
            ! [ -e ../${package}_${upstream_version}.orig.tar.bz2 ]; then
            if [ -z $DEBIAN_TAG ]; then
                file_upstream_version="${upstream_version%~*}"
                if [ -f ../${package}_${file_upstream_version#*:}*.orig.tar.* ]; then
                    # We have a minor package and its orig tarball in the repository
                    for suffix in gz xz bz2; do
                        if [ -f ../${package}_${file_upstream_version#*:}*.orig.tar.${suffix} ]; then
                            # We just must create a new one with the snapshot version number
                            ln ../${package}_${file_upstream_version#*:}*.orig.tar.${suffix} ../${package}_${upstream_version#*:}.orig.tar.${suffix}
                        fi
                    done
                else
                    git archive -o ../${package}_${upstream_version}.orig.tar.gz HEAD
                fi
            else
                if git tag -l | grep "^${UPSTREAM_TAG}$" ; then
                    git archive -o ../${package}_${upstream_version}.orig.tar.gz ${UPSTREAM_TAG}
                elif git tag -l | grep "^v${UPSTREAM_TAG}$" ; then
                    git archive -o ../${package}_${upstream_version}.orig.tar.gz v${UPSTREAM_TAG}
                else
                    echo "Cannot build tarball ${package}_${upstream_version}.orig.tar.gz from upstream tag ${UPSTREAM_TAG}"
                    exit 1
                fi
            fi
        fi
    fi
    # Removing the pscheduler packages we're not building, to save disk space on build host
    rm -rf "${BASE_DIR}/${SRC_DIR}/!(${package_dir}*)"
    rm -rf "${BASE_DIR}/${SRC_DIR}/.git"
else
    # Or calling gbp for the other packages
    gbp buildpackage $GBP_OPTS
fi
[ $? -eq 0 ] || exit 1

# Remove the GIT_BUILDING_REPO in case it re-emerged (with the --git-submodules option)
if [ "${PKG}" = "maddash" ]; then
    git submodule deinit -f ${GIT_BUILDING_REPO}
fi

# Build the source package
# TODO: we should do that through cowbuilder/pbuilder to make sure the build environment is minimal
# The minimal environement is created with `debootstrap --variant=minbase`
buildpackage_options="-nc -d -S -i -I"
if ! grep -q '(native)' debian/source/format ; then
    buildpackage_options=$buildpackage_options" --source-option=--unapply-patches"
fi
dpkg-buildpackage ${dpkgsign} ${buildpackage_options}
[ $? -eq 0 ] || exit 1
if [ "$pscheduler_dir_level" ]; then
    # With pscheduler repository structure, we must move the artefacts some levels up
    cd ..
    mv ${package}_* ${BASE_DIR}
    cd ${BASE_DIR}/${SRC_DIR}
fi
echo -e "\nPackage source for ${PKG} is built.\n"

# Run Lintian on built package
cd ..
lintian --show-overrides ${PKG}*.dsc
