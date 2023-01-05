#!/bin/bash
# Icinga 2 Docker image | (c) 2020 Icinga GmbH | GPLv2+
set -exo pipefail

mkimg () {
	env INPUT_FETCH-DEPTH=0 node /actions/checkout/dist/index.js |grep -vFe ::add-matcher::

	docker buildx create --use
	/docker-icinga2/build.bash . "$@"

	STATE_isPost=1 node /actions/checkout/dist/index.js
}

login () {
	if [ "$(tr -d '\n' <<<"$DOCKER_HUB_PASSWORD" |wc -c)" -gt 0 ]; then
		docker login -u icingaadmin --password-stdin <<<"$DOCKER_HUB_PASSWORD"
	fi
}

case "$GITHUB_EVENT_NAME" in
	pull_request)
		mkimg all
		;;
	push)
		grep -qEe '^refs/heads/.' <<<"$GITHUB_REF"
		login
		mkimg push "$(cut -d / -f 3- <<<"$GITHUB_REF" |tr / -)"
		;;
	release)
		grep -qEe '^refs/tags/v[0-9]' <<<"$GITHUB_REF"
		login
		mkimg push "$(cut -d v -f 2- <<<"$GITHUB_REF")"
		;;
	*)
		echo "Unknown event: $GITHUB_EVENT_NAME" >&2
		false
		;;
esac
