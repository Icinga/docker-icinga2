#!/bin/bash
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

docker build -f "${BLDCTX}/action-base.Dockerfile" -t icinga/icinga2-builder "$BLDCTX"
docker build -f "${BLDCTX}/deps.Dockerfile" -t icinga/icinga2-deps "$BLDCTX"

docker run --rm -i \
	-v "${I2SRC}:/i2src:ro" \
	-v "${BLDCTX}:/bldctx:ro" \
	-v "$(printf %s ~/.ccache):/root/.ccache" \
	-v /var/run/docker.sock:/var/run/docker.sock \
	icinga/icinga2-builder bash <<EOF
set -exo pipefail

git -C /i2src archive --prefix=i2cp/ HEAD |tar -xC /
cp -r /i2src/.git /i2cp
cd /i2cp

/bldctx/compile.bash
docker build -f /bldctx/Dockerfile -t icinga/icinga2 .
EOF
