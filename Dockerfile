# Icinga 2 Docker image | (c) 2020 Icinga GmbH | GPLv2+

FROM golang:bullseye as entrypoint

COPY entrypoint /entrypoint

WORKDIR /entrypoint
RUN ["go", "build", "."]


FROM buildpack-deps:scm as clone-plugins
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


FROM debian:bullseye-slim as build-plugins
SHELL ["/bin/bash", "-exo", "pipefail", "-c"]

RUN apt-get update ;\
	apt-get install --no-install-{recommends,suggests} -y \
		autoconf automake make ;\
	apt-get clean ;\
	rm -vrf /var/lib/apt/lists/*

COPY --from=clone-plugins /check_mssql_health /check_mssql_health
COPY --from=clone-plugins /check_nwc_health /check_nwc_health
COPY --from=clone-plugins /check_postgres /check_postgres

RUN cd /check_mssql_health ;\
	mkdir bin ;\
	autoconf ;\
	autoreconf ;\
	./configure "--build=$(uname -m)-unknown-linux-gnu" --libexecdir=/usr/lib/nagios/plugins ;\
	make ;\
	make install "DESTDIR=$(pwd)/bin"

RUN cd /check_nwc_health ;\
	mkdir bin ;\
	autoreconf ;\
	./configure "--build=$(uname -m)-unknown-linux-gnu" --libexecdir=/usr/lib/nagios/plugins ;\
	make ;\
	make install "DESTDIR=$(pwd)/bin"

RUN cd /check_postgres ;\
	mkdir bin ;\
	perl Makefile.PL INSTALLSITESCRIPT=/usr/lib/nagios/plugins ;\
	make ;\
	make install "DESTDIR=$(pwd)/bin" ;\
	rm -rf bin/usr/local/man
	# Otherwise: cannot copy to non-directory: /var/lib/docker/overlay2/r1tfzp762j3qxieib2fy3230x/merged/usr/local/man


FROM debian:bullseye-slim as build-icinga2
SHELL ["/bin/bash", "-exo", "pipefail", "-c"]

RUN apt-get update ;\
	apt-get install --no-install-{recommends,suggests} -y \
		bison cmake flex g++ git \
		libboost{,-{context,coroutine,date-time,filesystem,iostreams,program-options,regex,system,test,thread}}1.74-dev \
		libedit-dev libmariadb-dev libpq-dev libssl-dev make ;\
	apt-get install --no-install-{recommends,suggests} -y ccache ;\
	apt-get clean ;\
	rm -vrf /var/lib/apt/lists/*

COPY --from=icinga2-git . /icinga2-src/.git
RUN git -C /icinga2-src checkout .

RUN mkdir /icinga2-bin
RUN mkdir /icinga2-build
WORKDIR /icinga2-build

RUN PATH="/usr/lib/ccache:$PATH" cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_SYSCONFDIR=/etc \
	-DCMAKE_INSTALL_LOCALSTATEDIR=/var -DICINGA2_RUNDIR=/run \
	-DICINGA2_SYSCONFIGFILE=/etc/sysconfig/icinga2 -DICINGA2_WITH_{COMPAT,LIVESTATUS}=OFF /icinga2-src

RUN --mount=type=cache,target=/root/.ccache make
RUN make test
RUN make install DESTDIR=/icinga2-bin
RUN rm /icinga2-bin/etc/icinga2/features-enabled/mainlog.conf

RUN strip -g /icinga2-bin/usr/lib/*/icinga2/sbin/icinga2
RUN strip -g /icinga2-bin/usr/lib/nagios/plugins/check_nscp_api
RUN rm -rf /icinga2-bin/usr/share/doc/icinga2/markdown


FROM debian:bullseye-slim as icinga2

RUN ["/bin/bash", "-exo", "pipefail", "-c", "apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install --no-install-{recommends,suggests} -y ca-certificates curl dumb-init libboost-{context,coroutine,date-time,filesystem,iostreams,program-options,regex,system,thread}1.74.0 libcap2-bin libedit2 libldap-common libmariadb3 libmoosex-role-timer-perl libpq5 libssl1.1 mailutils monitoring-plugins msmtp{,-mta} openssh-client openssl; apt-get clean; rm -vrf /var/lib/apt/lists/*"]

COPY --from=entrypoint /entrypoint/entrypoint /entrypoint

RUN ["adduser", "--system", "--group", "--home", "/var/lib/icinga2", "--disabled-login", "--force-badname", "--no-create-home", "--uid", "5665", "icinga"]

COPY --from=build-plugins /check_mssql_health/bin/ /
COPY --from=build-plugins /check_nwc_health/bin/ /
COPY --from=build-plugins /check_postgres/bin/ /
COPY --from=clone-plugins /check_ssl_cert/check_ssl_cert /usr/lib/nagios/plugins/check_ssl_cert

ENTRYPOINT ["/entrypoint"]

COPY --from=build-icinga2 /icinga2-bin/ /

RUN ["install", "-o", "icinga", "-g", "icinga", "-d", "/data"]
RUN ["bash", "-exo", "pipefail", "-c", "for d in /etc/icinga2 /var/*/icinga2; do mkdir -p $(dirname /data-init$d); mv $d /data-init$d; ln -vs /data$d $d; done"]

EXPOSE 5665
USER icinga
CMD ["icinga2", "daemon"]


FROM icinga2 as test-icinga2
RUN ["icinga2", "daemon", "-C"]


FROM icinga2
