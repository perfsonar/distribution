#!/bin/bash
# Usage info
show_help() {
    cat << EOF

    Usage: ${0##*/} [-admnqv] [-c commit_options] [-t tag_options]

    This script makes a pscheduler release. It loops on all pscheduler Debian packages
    and check if the package is in a releasable state by calling make-release.sh

    If all goes well, a new commit and a tag are made and added to the repository.

    You can call this script with the following args:
        -a: add modified files to the commit (use \`git commit -a\`)
        -c: additional git options to be passed to \`git commit\`
        -d: don't update distribution submodule
        -n: performs a dry-run
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
v=0                     # no verbose
vout="/dev/null"        # no output
mr_n=""                 # no dry run
mr_m=""                 # not a minor-package
update_distribution=1   # update distribution submodule

# Parsing options
while getopts "ac:dnt:v" OPT; do
    case $OPT in
        a) commit_a="-a" ;;
        c) commit_options=$OPTARG ;;
        d) update_distribution=0 ;;
        n)
            dry_run=1
            mr_n="-n"
            ;;
        t) tag_options=$OPTARG ;;
        v) 
            v=1
            vout="/dev/stdout"
            mr_v="-v"
            verbose "\033[1mI'm running in verbose mode.\033[0m" ;;
        '?')
            show_help >&2
            exit 1 ;;
    esac
done
shift $((OPTIND-1))

# Loop on all pscheduler packages (new packages would need to be added here)
for p in pscheduler-* python-pscheduler; do
    case "$p" in
        "pscheduler-rpm")
            verbose "$p doesn't exist for Debian, we won't release it."
            continue
            ;;
        "python-pscheduler")
            pp="pscheduler"
            mr_m="-m"
            ;;
        *)
            pp=$p
            ;;
    esac

    cd $p
    if [ -d debian ]; then
        upper_dir=".."
    else
        # Check if the Debian package is in a subdirectory
        cd $pp
        if [ -d debian ]; then
            upper_dir="../.."
        else
            error "$pp doesn't look like a package I can release, maybe you need to correct the list of packages?"
        fi
    fi
    # Run make-release.sh to check if everything is right for the current package
    verbose "Checking $p is ready for release."
    if ! ${upper_dir}/distribution/debian/make-release.sh $mr_v $mr_n $mr_m -d -g > $vout; then
        error "I cannot release pscheduler because of $p"
    fi
    cd ${upper_dir}
done

# Get the final tag from pscheduler-bundle-full
cd pscheduler-bundle-full
OUT=`../distribution/debian/make-release.sh -d -g | tail -1`
VERSION=${OUT%% *}
TAG=${OUT##* }
cd ..
verbose ""
echo -e "All looks fine, we're now going to release \033[1;32mpscheduler\033[0m at \033[1;32m${VERSION}\033[0m to the local git repo."
echo -e "This release will be tagged as \033[1;32m${TAG}\033[0m."
if [[ $dry_run -eq 1 ]]; then
    v=1
    if [[ $update_distribution -eq 1 ]]; then
        verbose "We will update the distribution submodule to latest commit on master."
    fi
    verbose "\033[1mReady to release \033[1;32mpscheduler ($VERSION)\033[1;39m with tag \033[1;32m$TAG\033[0m, but this is a dry run, I haven't touch a thing."
    exit
fi

if [[ $update_distribution -eq 1 ]]; then
    # Update the distribution submodule to latest master commit
    verbose "Updating the distribution submodule to latest commit on master."
    cd distribution
    git checkout -q master
    if [[ $v -eq 0 ]]; then
        git pull -q
    else
        git pull
    fi
    cd ..
    git add distribution
fi

# Perform the git commit and add the tag
echo
git commit ${commit_a} ${commit_options} -m "Releasing pscheduler (${VERSION})"
git tag ${tag_options} ${TAG}
echo
echo "If you're happy with the commit and tag above, you just need to push that away!"

