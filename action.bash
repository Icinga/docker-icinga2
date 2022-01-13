#!/bin/bash
# Icinga 2 Docker image | (c) 2020 Icinga GmbH | GPLv2+
set -exo pipefail

TARGET=icinga/icinga2

mkimg () {
	test -n "$TAG"

	env INPUT_FETCH-DEPTH=0 node /actions/checkout/dist/index.js |grep -vFe ::add-matcher::

	/docker-icinga2/build.bash .

	STATE_isPost=1 node /actions/checkout/dist/index.js
}

push () {
	test -n "$TAG"

	if [ "$(tr -d '\n' <<<"$DOCKER_HUB_PASSWORD" |wc -c)" -gt 0 ]; then
		docker login -u icingaadmin --password-stdin <<<"$DOCKER_HUB_PASSWORD"
		docker tag "$TARGET" "${TARGET}:$TAG"
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
		TAG="$(cut -d / -f 3- <<<"$GITHUB_REF" |tr / -)"
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
