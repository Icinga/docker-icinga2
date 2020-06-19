#!/bin/bash
set -exo pipefail

TARGET=icinga/icinga2

cache () {
	INPUT_KEY=docker-image/ccache INPUT_PATH=ccache \
		STATE_CACHE_KEY=1 STATE_CACHE_RESULT=2 \
		node "/actions/cache/dist/${1}/index.js"
}

mkimg () {
	test -n "$TAG"

	node /actions/checkout/dist/index.js |grep -vFe ::add-matcher::
	cache restore

	export PATH="/usr/lib/ccache:$PATH"
	mkdir -p ccache
	ln -vs "$(pwd)/ccache" ~/.ccache

	mkdir icinga2-bin
	mkdir build
	cd build

	cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_SYSCONFDIR=/etc \
		-DCMAKE_INSTALL_LOCALSTATEDIR=/var -DICINGA2_RUNDIR=/run \
		-DICINGA2_SYSCONFIGFILE=/etc/sysconfig/icinga2 -DICINGA2_WITH_{COMPAT,LIVESTATUS}=OFF ..

	make
	make test

	make install "DESTDIR=$(pwd)/../icinga2-bin"

	cd ..

	cache save
	docker build -f /Dockerfile -t "${TARGET}:$TAG" .

	STATE_isPost=1 node /actions/checkout/dist/index.js

	docker save "${TARGET}:$TAG" |gzip >docker-save.tgz
	INPUT_NAME=docker-image INPUT_PATH=docker-save.tgz node /actions/upload-artifact/dist/index.js
	rm docker-save.tgz
}

push () {
	test -n "$TAG"

	if [ "$(tr -d '\n' <<<"$DOCKER_HUB_PASSWORD" |wc -c)" -gt 0 ]; then
		docker login -u icingaadmin --password-stdin <<<"$DOCKER_HUB_PASSWORD"
		docker push "${TARGET}:$TAG"
		docker logout
	fi
}

case "$GITHUB_EVENT_NAME" in
	pull_request)
		grep -qEe '^refs/pull/[0-9]+' <<<"$GITHUB_REF"
		TAG="pr$(grep -oEe '[0-9]+' <<<"$GITHUB_REF")"
		mkimg
		;;
	push)
		grep -qEe '^refs/heads/.' <<<"$GITHUB_REF"
		TAG="$(cut -d / -f 3- <<<"$GITHUB_REF")"
		mkimg
		push
		;;
	release)
		grep -qEe '^refs/tags/v[0-9]' <<<"$GITHUB_REF"
		TAG="$(cut -d v -f 2- <<<"$GITHUB_REF")"
		mkimg
		push
		;;
	*)
		echo "Unknown event: $GITHUB_EVENT_NAME" >&2
		false
		;;
esac
