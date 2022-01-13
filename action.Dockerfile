# Icinga 2 Docker image | (c) 2020 Icinga GmbH | GPLv2+

FROM buildpack-deps:scm as clone
SHELL ["/bin/bash", "-exo", "pipefail", "-c"]

RUN mkdir actions ;\
	cd actions ;\
	git clone --bare https://github.com/actions/checkout.git ;\
	git -C checkout.git archive --prefix=checkout/ v2 |tar -x ;\
	rm -rf *.git


FROM docker

RUN ["apk", "add", "--no-cache", "bash", "git", "nodejs", "perl"]
COPY --from=clone /actions /actions
COPY --from=docker/buildx-bin /buildx /usr/libexec/docker/cli-plugins/docker-buildx
ADD . /docker-icinga2

CMD ["/docker-icinga2/action.bash"]
