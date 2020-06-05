#!/usr/bin/env bash
# This script will finish the preparation of the Vagrant Debian build host
# to have everything ready to build perfSONAR Debian packages.
# It should be run as a normal user (i.e. vagrant).

echo -e "\033[1;36mSetting up vagrant user environment.\033[0m"

# Get root of shared repo
if [ "${SHARED_REPO_PREFIX}" ]; then
    export PS_SHARED_REPO=${SHARED_REPO_PREFIX}
else
    export PS_SHARED_REPO="${BASH_SOURCE[0]}"
fi

# Add useful pbuilder hooks
sudo cp ${PS_SHARED_REPO}/distribution/debian/d9-host-files/pbuilder-hook.d/* /var/cache/pbuilder/hook.d/

# Adding pS building scripts
cp ${PS_SHARED_REPO}/distribution/debian/d9-host-files/pbuilderrc /home/${USER}/.pbuilderrc
cp ${PS_SHARED_REPO}/distribution/debian/d9-host-files/scripts/ps-cowbuilder-build /home/${USER}/
chmod +x /home/${USER}/ps-cowbuilder-build

# Make sure result directory in the Vagrant share is existing
if [ "${PS_SHARED_REPO}" = "/vagrant" ]; then
    RESULT_DIR=${PS_SHARED_REPO}/result
else
    RESULT_DIR=${PS_SHARED_REPO}/../result
fi
[ -d ${RESULT_DIR} ] || mkdir -p ${RESULT_DIR}

# Install user dotfiles if supplied
# See https://github.com/tonin/osx.dotfiles for example
# Beware that is you deploy your own ssh public keys, you'll need to tweak vagrant.ssh configuration
# For example, with config.ssh.keys_only = false
if [ -n "${VAGRANT_USER_DOTFILES}" ]; then
    echo -e "\033[1;36mCloning dotfiles user repo.\033[0m"
    mkdir -p /home/${USER}/.config
    if [ ! -d /home/${USER}/.config/dotfiles ]; then
        git clone ${VAGRANT_USER_DOTFILES} /home/${USER}/.config/dotfiles
    else
        cd /home/${USER}/.config/dotfiles
        git pull
    fi
fi
if [ -n "${VAGRANT_USER_DOTFILES_DEPLOY}" ]; then
    echo -e "\033[1;36mDeploying user dotfiles.\033[0m"
    /home/${USER}/.config/dotfiles/${VAGRANT_USER_DOTFILES_DEPLOY}
fi
