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

I2SRC="$(realpath "$I2SRC")"
BLDCTX="$(realpath "$(dirname "$0")")"
TMPBLDCTX="$(mktemp -d)"

trap "rm -rf $TMPBLDCTX" EXIT

cp -a "${BLDCTX}/." "$TMPBLDCTX"
git clone "file://${I2SRC}/.git" "${TMPBLDCTX}/icinga2-src"

docker build -f "${TMPBLDCTX}/Dockerfile" -t icinga/icinga2 "$TMPBLDCTX"
docker run --rm icinga/icinga2 icinga2 daemon -C
