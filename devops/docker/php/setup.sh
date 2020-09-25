#!/usr/bin/env sh

icu=${ICU:?}

cd files

if [ ! -f "icu-${icu}.tgz" ]; then
    curl -sS -o "icu-${icu}.tgz" --fail -L "https://github.com/unicode-org/icu/releases/download/release-$(echo ${icu} | tr '.' '-')/icu4c-$(echo ${icu} | tr '.' '_')-src.tgz"
    [ $? -ne 0 ] && cd - && exit 1
fi

cd - >/dev/null
