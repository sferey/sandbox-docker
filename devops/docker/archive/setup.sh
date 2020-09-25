#!/usr/bin/env sh

app_dir=${APP_DIR:?}
staging_env=${STAGING_ENV:?}
git="git -C ${app_dir}"
hash=$(${git} rev-parse --verify -q --short HEAD)
[ $? -ne 0 ] && echo 'Invalid GIT ref' >&2 && exit 1
[ "$(${git} status --porcelain)" ] && echo 'WARNING: local changes are EXCLUDED in archive!' >&2
[ ! "$(${git} branch -r --contains "${hash}")" ] && echo 'WARNING: un-pushed commits are INCLUDED in archive!' >&2

cd dist

if [ ! -f "sha/${hash}.tgz" ]; then
    mkdir -p sha && ${git} archive --output "$(pwd)/sha/${hash}.tgz" --format tgz "${hash}"
    [ $? -ne 0 ] && cd - && exit 1
fi
ln -sf "sha/${hash}.tgz" "${staging_env}-current.tgz"
[ $? -ne 0 ] && cd - && exit 1

cd - >/dev/null
