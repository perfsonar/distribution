#!/bin/bash
# Usage info
show_help() {
    cat << EOF

    Usage: ${0##*/} [-admnqv] [-c commit_options] [-t tag_options]

    This script releases  a  new  version  (final,  RC,  beta  or  alpha)  of  a
    perfSONAR Debian package. It looks for the version of  the  package  in  the
    debian/changelog file. It creates a new git  commit  with  all  files  ready
    to be commited and add the corresponding tag.

    The file debian/changelog is  automatically  modified  by  this  script  and
    added to the git commit.  Debian  quilt  patches  are  refreshed  and  added
    as well, as is the distribution submodule.

    Two environment variables can be used to generate the changelog:
        - DEBEMAIL: the email mentioned in the changelog signature
        - DEBFULLNAME: the name mentioned in the changelog signature
    If those  2  variables  are  not  defined,  then  your  git  user.email  and
    user.name will be used instead.

    You can call this script with the following args:
        -a: add modified files to the commit (use \`git commit -a\`)
        -c: additional git options to be passed to \`git commit\`
        -d: don't update distribution submodule
        -g: don't do any git action (no commit, no tag)
        -m: releases a minor package
        -n: performs a dry-run
        -q: don't refresh quilt patches
        -t: additional git options to be passed to \`git tag\`
        -v: verbose
EOF
}

# Error handler
error() {
    echo -e "\033[1m$1\033[0m" >&2
    [ $v -eq 0 ] || echo -e "\033[1;31mBetter I stop now, before doing any commit to the local repo.\033[0m" >&2
    exit 1
}

# Verbose handler
verbose() {
    [ $v -eq 0 ] || echo -e $1
}

# Defaults
v=0
dry_run=0
no_git=0
minor_pkg=0
quilt_refresh=1
update_distribution=1

# Parsing options
while getopts "ac:dgmnt:v" OPT; do
    case $OPT in
        a) commit_a="-a" ;;
        c) commit_options=$OPTARG ;;
        d) update_distribution=0 ;;
        g) no_git=1 ;;
        m) minor_pkg=1 ;;
        n) dry_run=1 ;;
        q) quilt_refresh=0 ;;
        t) tag_options=$OPTARG ;;
        v) 
            v=1
            verbose "\033[1mI'm running in verbose mode.\033[0m" ;;
        '?')
            show_help >&2
            exit 1 ;;
    esac
done
shift $((OPTIND-1))

# Some sanity checks
if [[ -f debian/changelog && -f debian/gbp.conf ]]; then
    verbose "debian/changelog and debian/gbp.conf are present, that's a good start."
else
    error "${PWD##*\/} doesn't look like a Debian packaging tree, I cannot find debian/changelog or debian/gbp.conf."
fi

# Check Debian branch
BRANCH=`git branch --list | awk '/^\* .*$/ {print $2}'`
DEBIAN_BRANCH=`awk -F '=' '/debian-branch/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' debian/gbp.conf`
if [ "$BRANCH" = "$DEBIAN_BRANCH" ]; then
    verbose "Current git branch ($BRANCH) matches the gbp configured branch ($DEBIAN_BRANCH)."
else
    error "Your current git branch ($BRANCH) is not the same as the branch configured for gbp ($DEBIAN_BRANCH)."
fi

# Get some package information from the repo
PKG=`awk 'NR==1 {print $1}' debian/changelog`
PKG_VERSION=`awk 'NR==1 {gsub(/^\(|\)$/, "", $2); print $2}' debian/changelog`
CH_DISTRO=`awk 'NR==1 {gsub(/;$/, "", $3); print $3}' debian/changelog`
BUILD_DISTRO=`awk -F 'DIST=' '/builder/ {gsub(/[ \t]+.*$/, "", $2); print $2}' debian/gbp.conf`

# The versions and tags need to conform to our policy detailed at https://github.com/perfsonar/project/wiki/Versioning
if grep -q '(native)' debian/source/format ; then
    # Native package don't have release numbers, only a version number
    VERSION=${PKG_VERSION}
    # We don't have an upstream version either
    UPSTREAM_VERSION=${VERSION//\~*/}
    TAG_VERSION=${PKG_VERSION/\~bpo/_bpo}
    TAG_VERSION=${TAG_VERSION//\~/-}
    if [ "${minor_pkg}" -eq 1 ]; then
        DEBIAN_TAG="debian/${BUILD_DISTRO}/${PKG}-${TAG_VERSION}"
    else
        DEBIAN_TAG="debian/${BUILD_DISTRO}/${TAG_VERSION}"
    fi
else
    VERSION=${PKG_VERSION%-*}
    PKG_REL="-${PKG_VERSION##*-}"
    UPSTREAM_VERSION=${VERSION/\~/-}
    if [ "${minor_pkg}" -eq 1 ]; then
        DEBIAN_TAG="debian/${BUILD_DISTRO}/${PKG}-${UPSTREAM_VERSION}${PKG_REL//\~/_}"
    else
        DEBIAN_TAG="debian/${BUILD_DISTRO}/${UPSTREAM_VERSION}${PKG_REL//\~/_}"
        # Check there is a corresponding upstream tag
        if ! git tag -l | grep -q "^${UPSTREAM_VERSION}$" ; then
            error "$PKG_VERSION of $PKG doesn't seem to have a corresponding upstream tag (something like ${UPSTREAM_VERSION})."
        fi
    fi
fi

# Check there is not an already existing Debian tag
if git tag -l | grep -q "^${DEBIAN_TAG}$" ; then
    error "$DEBIAN_TAG is already existing in this repository."
fi

# Check distro field in debian/changelog
if [ "$VERSION" = "$UPSTREAM_VERSION" ]; then
    if ! grep -q '(native)' debian/source/format ; then
        verbose "We have a final release! Celebrate for $PKG_VERSION coming from upstream $UPSTREAM_VERSION"
    else
        verbose "We have a final release! Celebrate for $PKG_VERSION (native package)."
    fi
    REL="release"
else
    if ! grep -q '(native)' debian/source/format ; then
        verbose "We have an alpha, beta or candidate release: $PKG_VERSION coming from upstream $UPSTREAM_VERSION"
    else
        verbose "We have an alpha, beta or candidate release: $PKG_VERSION (native package)."
    fi
    REL="staging"
fi
PS_DEB_REP="perfsonar-${BUILD_DISTRO}-${REL}"
# We can have UNRELEASED as distro (we will change it later on), or it must be the correct $PS_DEB_REP
if [[ "$CH_DISTRO" = "UNRELEASED" || "$CH_DISTRO" = "$PS_DEB_REP" ]]; then
    verbose "The distribution field in the debian/changelog file looks good: $CH_DISTRO."
else
    error "The distribution field in the debian/changelog of ${PWD##*\/} should be: $PS_DEB_REP (or UNRELEASED)"
fi

# Replace debian/changelog signature line with commiter or DEBIAN_EMAIL info
if [ -z "$DEBEMAIL" ]; then
    DEBEMAIL=`git config user.email`
    DEBFULLNAME=`git config user.name`
fi
# We use a date format that is working on both Linux and BSD
DATE=`LANG=C date "+%a, %d %b %Y %T %z"`
FINISH_LINE=" -- ${DEBFULLNAME} <${DEBEMAIL}>  ${DATE}"
verbose "The package signature line will be:"
[ $v -eq 0 ] || printf "${FINISH_LINE}\n"

# Make the git commit and tag
echo -e "We're now going to release \033[1;32m${PKG}\033[0m at \033[1;32m${PKG_VERSION}\033[0m for \033[1;32m${PS_DEB_REP}\033[0m to the local git repo."
echo -e "This release will be tagged as \033[1;32m${DEBIAN_TAG}\033[0m."
if [[ $dry_run -eq 1 ]]; then
    if [[ $quilt_refresh -eq 1 && -d debian/patches ]]; then
        verbose "We will try to refresh quilt patches to latest merge."
    fi
    if [[ $update_distribution -eq 1 ]]; then
        verbose "We will update the distribution submodule to latest commit on master."
    fi
    v=1
    verbose "\033[1mThis is a dry run, I haven't touch a thing.\033[0m"
    exit
fi

# Refresh quilt patches if needed (if a refresh is not possible, this will stop and manual correction should happen)
if [[ $quilt_refresh -eq 1 && -s debian/patches/series ]]; then
    verbose "Trying to refresh quilt patches to latest merge."
    QUILT_PATCHES="debian/patches"
    QUILT_REFRESH_ARGS="-p ab --no-timestamps --no-index"
    quilt --quiltrc - push -aq --refresh > /dev/null
    quilt pop -aq > /dev/null
    git add debian/patches
fi

if [[ $update_distribution -eq 1 ]]; then
    # Update the distribution submodule to latest master commit
    verbose "Updating the distribution submodule to latest commit on master."
    if [ "${minor_pkg}" -eq 1 ]; then
        cd ..
    fi
    cd distribution
    git checkout -q master
    if [[ $v -eq 0 ]]; then
        git pull -q
    else
        git pull
    fi
    cd ..
    git add distribution
    if [ "${minor_pkg}" -eq 1 ]; then
        cd ${PKG}
    fi
fi

# Actually change the debian/changelog file
n=`grep -nm 1 " -- " debian/changelog | awk -F ':' '{print $1}'`
TMP_FILE=`mktemp`
sed "${n}s/^ -- .* [+-][0-9]\{4\}/${FINISH_LINE}/" debian/changelog > $TMP_FILE
sed "1s/ UNRELEASED;/ $PS_DEB_REP;/" $TMP_FILE > debian/changelog
/bin/rm $TMP_FILE
git add debian/changelog

if [[ $no_git -eq 0 ]]; then
    # Perform the git commit and add the tag
    echo
    git commit ${commit_a} ${commit_options} -m "Releasing ${PKG} (${PKG_VERSION})"
    git tag ${tag_options} ${DEBIAN_TAG}
    echo
    echo "If you're happy with the commit and tag above, you just need to push that away!"
else
    # Or return the version and the tag
    echo ${PKG_VERSION} ${DEBIAN_TAG}
fi

