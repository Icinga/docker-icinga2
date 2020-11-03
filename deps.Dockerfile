# Icinga 2 Docker image | (c) 2020 Icinga GmbH | GPLv2+

FROM golang:buster as entrypoint

COPY entrypoint /entrypoint

WORKDIR /entrypoint
RUN ["go", "build", "."]


FROM buildpack-deps:scm as clone
SHELL ["/bin/bash", "-exo", "pipefail", "-c"]

RUN git clone --bare https://github.com/lausser/check_mssql_health.git ;\
	git -C check_mssql_health.git archive --prefix=check_mssql_health/ 747af4c3c261790341da164b58d84db9c7fa5480 |tar -x ;\
	git clone --bare https://github.com/lausser/check_nwc_health.git ;\
	git -C check_nwc_health.git archive --prefix=check_nwc_health/ a5295475c9bbd6df9fe7432347f7c5aba16b49df |tar -x ;\
	git clone --bare https://github.com/bucardo/check_postgres.git ;\
	git -C check_postgres.git archive --prefix=check_postgres/ 58de936fdfe4073413340cbd9061aa69099f1680 |tar -x ;\
	git clone --bare https://github.com/matteocorti/check_ssl_cert.git ;\
	git -C check_ssl_cert.git archive --prefix=check_ssl_cert/ 1e72259a9c1cd8c60e229725293c51e03c3ba814 |tar -x ;\
	rm -rf *.git


FROM debian:buster-slim as build
SHELL ["/bin/bash", "-exo", "pipefail", "-c"]

RUN apt-get update ;\
	apt-get install --no-install-{recommends,suggests} -y \
		autoconf automake make ;\
	apt-get clean ;\
	rm -vrf /var/lib/apt/lists/*

COPY --from=clone /check_mssql_health /check_mssql_health
COPY --from=clone /check_nwc_health /check_nwc_health
COPY --from=clone /check_postgres /check_postgres

RUN cd /check_mssql_health ;\
	mkdir bin ;\
	autoconf ;\
	autoreconf ;\
	./configure --libexecdir=/usr/lib/nagios/plugins ;\
	make ;\
	make install "DESTDIR=$(pwd)/bin"

RUN cd /check_nwc_health ;\
	mkdir bin ;\
	autoreconf ;\
	./configure --libexecdir=/usr/lib/nagios/plugins ;\
	make ;\
	make install "DESTDIR=$(pwd)/bin"

RUN cd /check_postgres ;\
	mkdir bin ;\
	perl Makefile.PL INSTALLSITESCRIPT=/usr/lib/nagios/plugins ;\
	make ;\
	make install "DESTDIR=$(pwd)/bin"


FROM debian:buster-slim

RUN ["/bin/bash", "-exo", "pipefail", "-c", "export DEBIAN_FRONTEND=noninteractive; apt-get update; apt-get install --no-install-{recommends,suggests} -y libboost-{context,coroutine,date-time,filesystem,program-options,regex,system,thread}1.67 libedit2 libmariadb3 libmoosex-role-timer-perl libpq5 libssl1.1 mailutils monitoring-plugins openssl postfix; apt-get clean; rm -vrf /var/lib/apt/lists/*"]

COPY --from=entrypoint /entrypoint/entrypoint /entrypoint

COPY --from=icinga/docker-chown /docker-chown /docker-chown
RUN ["chmod", "06755", "/docker-chown"]

RUN ["adduser", "--system", "--group", "--home", "/var/lib/icinga2", "--disabled-login", "--force-badname", "--no-create-home", "--uid", "5665", "icinga"]

COPY --from=build /check_mssql_health/bin/ /
COPY --from=build /check_nwc_health/bin/ /
COPY --from=build /check_postgres/bin/ /
COPY --from=clone /check_ssl_cert/check_ssl_cert /usr/lib/nagios/plugins/check_ssl_cert

ENTRYPOINT ["/entrypoint"]
