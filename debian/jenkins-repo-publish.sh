#!/usr/bin/env bash
# This script publishes the packages build locally to the remote public repository
# It is meant to be run after new packages have been built

## reprepro defaults
export REPREPRO_BASE_DIR=/srv/repository
rm -f *.properties

## Get repositories content
set +x
uptime
uname -a

echo "Local repositories are in /srv/repository here is their current content"
ls -la /srv/repository
ls -la /srv/repository/dists

for DIST in 4.2 4.3 4.4; do
    for RELEASE in staging snapshot; do
        echo
        # Check the current content of the repository
        REPO="perfsonar-${DIST}-${RELEASE}"
        echo "Listing content of the local repository ${REPO}"
        repository_checker --list-repos ${REPO}
        echo -n "Total number of packages in ${REPO}: "
        repository_checker --list-repos ${REPO} | wc -l
        echo "––––––––––––––––––––––––––––––"
    done
done

echo
echo "Push the repository to the public repo server, in a staging space, deleting extraneous files"
rsync -av --delete /srv/repository/ jenkins@ps-deb-repo.qalab.geant.net:/var/www/html/repo-from-jenkins/
# Update the staging repo description page
ssh jenkins@ps-deb-repo.qalab.geant.net "~/deb-repo-info.pl -repo /var/www/html/repo-from-jenkins -html > /var/www/html/repo-from-jenkins/index.html"
echo
echo "Copy new packages into the final public repository (snapshot and staging only) and update the description page"
OUT=`ssh jenkins@ps-deb-repo.qalab.geant.net "reprepro --waitforlock 12 -b /var/www/html/debian update perfsonar-4.4-snapshot perfsonar-4.4-staging perfsonar-4.2-snapshot perfsonar-4.2-staging perfsonar-4.3-snapshot perfsonar-4.3-staging" 2>&1`
if [ ! $? -eq 0 ]; then
    echo
    echo "$OUT"
    echo "The main repository didn't want to take in the new snapshot and staging packages.  Update failed!"
    exit 1
fi
echo
echo "$OUT"
# Create a properties file per release that got updated.
PROP=`echo "$OUT" | awk '/^Retracking perfsonar-[0-9.a-z]+-[a-z]+.../ {gsub("\.\.\.","",$2);print "DISTRO="$2}'`
for p in $PROP; do
    echo $p > ${p##*=}.properties
done
ssh jenkins@ps-deb-repo.qalab.geant.net "~/deb-repo-info.pl -repo /var/www/html/debian -html > /var/www/html/debian/index.html"

# GÉANT repoo testing instance, should be removed when moving into production
#for server in test
#for server in test uat
#    do
#    echo
#    echo "Publish to the mirror of downloads.perfsonar.net public host (${server}-pspackages.geant.net)"
#    ssh jenkins@ps-deb-repo.qalab.geant.net "rsync -av --delete /var/www/html/debian/ psrepo@${server}-pspackages.geant.net:/var/www/html/debian/"
#done

