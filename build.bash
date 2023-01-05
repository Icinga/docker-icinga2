#!/bin/bash
# Icinga 2 Docker image | (c) 2020 Icinga GmbH | GPLv2+
set -exo pipefail

I2SRC="$1"

if [ -z "$I2SRC" ]; then
	cat <<EOF >&2
Usage: ${0} /icinga2/source/dir
EOF

	false
fi

if ! docker version; then
	echo 'Docker not found' >&2
	false
fi

if ! docker buildx version; then
	echo '"docker buildx" not found (see https://docs.docker.com/buildx/working-with-buildx/ )' >&2
	false
fi

I2SRC="$(realpath "$I2SRC")"
BLDCTX="$(realpath "$(dirname "$0")")"
TMPBLDCTX="$(mktemp -d)"

trap "rm -rf $TMPBLDCTX" EXIT

cp -a "${BLDCTX}/." "$TMPBLDCTX"
git clone "file://${I2SRC}/.git" "${TMPBLDCTX}/icinga2-src"

docker buildx build --platform "$(echo linux/{amd64,arm{/v7,64/v8}} |tr ' ' ,)" -f "${TMPBLDCTX}/Dockerfile" -t icinga/icinga2 "$TMPBLDCTX"
