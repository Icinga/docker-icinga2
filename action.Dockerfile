FROM buildpack-deps:scm as clone
SHELL ["/bin/bash", "-exo", "pipefail", "-c"]

RUN mkdir actions ;\
	cd actions ;\
	git clone --bare https://github.com/actions/checkout.git ;\
	git -C checkout.git archive --prefix=checkout/ v2 |tar -x ;\
	git clone --bare https://github.com/actions/upload-artifact.git ;\
	git -C upload-artifact.git archive --prefix=upload-artifact/ v2 |tar -x ;\
	rm -rf *.git


FROM docker

RUN ["apk", "add", "bash", "grep", "nodejs"]
COPY --from=clone /actions /actions

COPY action.bash Dockerfile /

CMD ["/action.bash"]
