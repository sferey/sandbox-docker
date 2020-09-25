#!/usr/bin/env sh

openssl=$(command -v openssl)

if [ ! -x "${openssl}" ]; then
    image=$(docker build --force-rm --tag "$(whoami)/openssl" -<<EOF
FROM alpine
RUN apk add --no-cache openssl
VOLUME /secrets
WORKDIR /secrets
ENTRYPOINT ["openssl"]
EOF
    )
    openssl="docker run --init -it --rm -v $(pwd):/secrets -u $(id -u):$(id -g) $(whoami)/openssl"
fi

${openssl} ${@}
