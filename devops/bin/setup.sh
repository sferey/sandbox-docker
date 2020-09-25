#!/usr/bin/env sh

staging_env=${1:?}
app_dir=${2:?}
project=${3:?}

cp -n "devops/environment/${staging_env}/.env.dist" "devops/environment/${staging_env}/.env"
set -a && . "devops/environment/${staging_env}/.env"
export COMPOSE_PROJECT_NAME=${project};
export APP_DIR=${app_dir};
export STAGING_ENV=${staging_env};

ret=0
for service in $(find devops/docker -mindepth 1 -maxdepth 2 -name setup.sh); do
    sh -xc "cd $(dirname "${service}"); ./setup.sh"
    [ $? -ne 0 ] && ret=1
done
[ ${ret} -ne 0 ] && exit 1

if [ -f devops/environment/base/setup.sh ]; then
    sh -xc 'cd devops/environment/base; ./setup.sh'
    [ $? -ne 0 ] && exit 1
fi

if [ -f "devops/environment/${staging_env}/setup.sh" ]; then
    sh -xc "cd devops/environment/${staging_env}; ./setup.sh"
    [ $? -ne 0 ] && exit 1
fi

exit 0
