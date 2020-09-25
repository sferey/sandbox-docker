#!/usr/bin/env sh

force=0; [ "$1" = -f ] && shift && force=1
read=0; [ "$1" = -r ] && shift && read=1
export=0; [ "$1" = -e ] && shift && export=1
file=${1:?}
json=${2:?}

php="docker run --init -i --rm -v $(pwd):/app -w /app -u $(id -u):$(id -g) composer php"
source='{}'; [ -f "${file}" ] && source=$(cat "${file}")
old=$(printf '%s' "${source}" | ${php} -r "var_export(json_decode(trim(file_get_contents('php://stdin')), true, 512, JSON_THROW_ON_ERROR));")

if [ ${export} -eq 1 ]; then
    ${php} -r "foreach (array_map('escapeshellarg', array_filter(${old}, 'is_string')) as \$k => \$v) { echo \"{\$k}={\$v}\n\"; }" > "${json}"
    exit $?
fi

if [ ${read} -eq 1 ]; then
    printf '%s' "${json}" | ${php} -r "echo (${old})[file_get_contents('php://stdin')] ?? '';"
    exit $?
fi

new=$(printf '%s' "${json}" | ${php} -r "var_export(json_decode(trim(file_get_contents('php://stdin')), true, 512, JSON_THROW_ON_ERROR));")
args="${new}, ${old}"; [ ${force} -eq 1 ] && args="${old}, ${new}"
output=$(${php} -r "echo json_encode(array_replace_recursive(${args}), JSON_PRETTY_PRINT|JSON_THROW_ON_ERROR);")
[ $? -ne 0 ] && exit 1

echo "${output}" > "${file}"
