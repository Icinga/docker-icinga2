FROM buildpack-deps:scm as clone
SHELL ["/bin/bash", "-exo", "pipefail", "-c"]

RUN git clone --bare https://github.com/lausser/check_mssql_health.git ;\
	git -C check_mssql_health.git archive --prefix=check_mssql_health/ 747af4c3c261790341da164b58d84db9c7fa5480 |tar -x ;\
	rm -rf *.git


FROM debian:buster-slim as build
SHELL ["/bin/bash", "-exo", "pipefail", "-c"]

RUN apt-get update ;\
	apt-get install --no-install-{recommends,suggests} -y \
		autoconf automake make ;\
	apt-get clean ;\
	rm -vrf /var/lib/apt/lists/*

COPY --from=clone /check_mssql_health /check_mssql_health

RUN cd /check_mssql_health ;\
	mkdir bin ;\
	autoconf ;\
	autoreconf ;\
	./configure --libexecdir=/usr/lib/nagios/plugins ;\
	make ;\
	make install "DESTDIR=$(pwd)/bin"


FROM debian:buster-slim

RUN ["/bin/bash", "-exo", "pipefail", "-c", "export DEBIAN_FRONTEND=noninteractive; apt-get update; apt-get install --no-install-{recommends,suggests} -y libboost-{context,coroutine,date-time,filesystem,program-options,regex,system,thread}1.67 libedit2 libmariadb3 libmoosex-role-timer-perl libpq5 libssl1.1 mailutils monitoring-plugins postfix; apt-get clean; rm -vrf /var/lib/apt/lists/*"]

RUN ["adduser", "--system", "--group", "--home", "/var/lib/icinga2", "--disabled-login", "--force-badname", "--no-create-home", "icinga"]

COPY --from=build /check_mssql_health/bin/ /
