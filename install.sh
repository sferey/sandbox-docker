#!/usr/bin/env sh

[ $# -ne 0 ] && echo "Usage: ${0}" && exit
[ "$(git status --porcelain)" ] && echo 'Working directory must be clean, please commit your changes first.' && exit 1

version=${SF:-''}
full=${FULL:-0}
commit=${GIT:-0}

echo 'Starting installation ...'

symfony=$(command -v symfony)
symfony_local=$(command -v "${HOME}/.symfony/bin/symfony")
composer=$(command -v composer)

if [ -x "${symfony}" ]; then
    echo "Using global Symfony installer at ${symfony} ..."
    unset composer
elif [ -x "${symfony_local}" ]; then
    echo "Using local Symfony installer at ${symfony_local} ..."
    symfony=${symfony_local}
    unset composer
elif [ -x "${composer}" ]; then
    echo "Using global Composer installer at ${composer} ..."
    unset symfony
else
    echo 'Using containerized Composer installer ...'
    mkdir -p "${HOME}/.composer"
    composer="docker run --rm \
        -v ${HOME}/.composer:/tmp/composer \
        -v $(pwd):/app -w /app \
        -u $(id -u):$(id -g) \
        -e COMPOSER_HOME=/tmp/composer"
    [ -t 1 ] && composer="${composer} -it"
    composer="${composer} composer"
    unset symfony
fi

cp -n devops/environment/dev/.env.dist devops/environment/dev/.env; . devops/environment/dev/.env
echo 'Development environment loaded ...'

tmp_dir=$(mktemp -d -t install-XXXXX --tmpdir=.); rm -rf "${tmp_dir}"

if [ -n "${symfony}" ]; then
    cmd="${symfony} new --no-git";
    [ -n "${version}" ] && cmd="${cmd} --version ${version}"
    [ ${full} -eq 1 ] && cmd="${cmd} --full"
    cmd="${cmd} ${tmp_dir}"
else
    skeleton='symfony/skeleton'; [ ${full} -eq 1 ] && skeleton='symfony/website-skeleton';
    v=${version}; [ ! -z "${v}" ] && [ $(echo "${v}" | awk -F"." '{print NF-1}') -lt 2 ] && v="${v}.*"
    cmd="${composer} create-project --remove-vcs ${skeleton} ${tmp_dir} ${v}"
fi

sh -xc "${cmd}"

[ $? -ne 0 ] && echo 'Installation failed ...' && rm -rf "${tmp_dir}" && exit 1

rm -f public/index.php && \
mv -f ${tmp_dir}/* . && cp -Rf "${tmp_dir}/." . && \
rm -rf "${tmp_dir}" && \

sed -i 's/Request::HEADER_X_FORWARDED_ALL ^ Request::HEADER_X_FORWARDED_HOST/Request::HEADER_X_FORWARDED_ALL/' public/index.php && \

echo "DATABASE_URL=mysql://${MYSQL_USER:?}:${MYSQL_PASSWORD:?}@db/${MYSQL_DATABASE:?}" >> .env.local && \
echo 'TRUSTED_PROXIES=10.0.0.0/8,172.16.0.0/12,192.168.0.0/18' >> .env.local && \
echo "TRUSTED_HOSTS='^localhost|web$'" >> .env.local && \

echo 'DATABASE_URL=sqlite:///:memory:' >> .env.test &&\

echo 'Initial source files created ...'

[ $? -ne 0 ] && echo 'Installation failed ...' && exit 1

if [ ${commit} -eq 1 ]; then
    [ ! -d .git ] && git init
    git add . && \
    git rm --cached "$0" && \
    git commit -m 'Initial project setup'
    [ $? -ne 0 ] && echo 'GIT commit failed ...'
fi

make build start
