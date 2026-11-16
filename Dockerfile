# Icinga 2 Docker image | (c) 2020 Icinga GmbH | GPLv2+

FROM golang:bookworm AS entrypoint

COPY entrypoint /entrypoint

WORKDIR /entrypoint
RUN ["go", "build", "."]

FROM debian:bookworm-slim AS build-icinga2
SHELL ["/bin/bash", "-exo", "pipefail", "-c"]

RUN apt-get update ;\
	apt-get upgrade -y;\
	apt-get install --no-install-{recommends,suggests} -y \
		bison cmake flex g++ git \
		libboost{,-{context,coroutine,date-time,filesystem,iostreams,program-options,regex,system,test,thread}}1.74-dev \
		libedit-dev libmariadb-dev libpq-dev libssl-dev libsystemd-dev make ;\
	apt-get install --no-install-{recommends,suggests} -y ccache ;\
	apt-get clean ;\
	rm -vrf /var/lib/apt/lists/*

COPY --from=icinga2-git . /icinga2-src/.git
RUN git -C /icinga2-src checkout .

RUN mkdir /icinga2-bin
RUN mkdir /icinga2-build
WORKDIR /icinga2-build

RUN PATH="/usr/lib/ccache:$PATH" cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_SYSCONFDIR=/etc \
	-DCMAKE_INSTALL_LOCALSTATEDIR=/var -DICINGA2_RUNDIR=/run -DUSE_SYSTEMD=ON \
	-DICINGA2_SYSCONFIGFILE=/etc/sysconfig/icinga2 -DICINGA2_WITH_{COMPAT,LIVESTATUS}=OFF /icinga2-src

RUN --mount=type=cache,target=/root/.ccache make
RUN CTEST_OUTPUT_ON_FAILURE=1 make test
RUN make install DESTDIR=/icinga2-bin
RUN rm /icinga2-bin/etc/icinga2/features-enabled/mainlog.conf

RUN strip -g /icinga2-bin/usr/lib/*/icinga2/sbin/icinga2
RUN strip -g /icinga2-bin/usr/lib/nagios/plugins/check_nscp_api
RUN rm -rf /icinga2-bin/usr/share/doc/icinga2/markdown


FROM debian:bookworm-slim AS icinga2

COPY --from=ghcr.io/icinga/icinga2-plugins-container:bookworm /usr/lib/nagios/plugins/* /usr/lib/nagios/plugins/
COPY --from=ghcr.io/icinga/icinga2-plugins-container:bookworm /plugins.cdx.json /usr/share/sbom/

RUN --mount=from=ghcr.io/icinga/icinga2-plugins-container:bookworm,target=/plugins ["/bin/bash", "-exo", "pipefail", "-c", "apt-get update; apt-get upgrade -y; export DEBIAN_FRONTEND=noninteractive; apt-get install --no-install-{recommends,suggests} -y bc ca-certificates curl dumb-init file libboost-{context,coroutine,date-time,filesystem,iostreams,program-options,regex,system,thread}1.74.0 libcap2-bin libedit2 libldap-common libmariadb3 libmoosex-role-timer-perl libpq5 libssl3 libsystemd0 mailutils msmtp{,-mta} openssh-client openssl $(cat /plugins/debian-packages); apt-get install --no-install-suggests -y monitoring-plugins; apt-get clean; rm -vrf /var/lib/apt/lists/*"]

COPY --from=entrypoint /entrypoint/entrypoint /entrypoint

RUN ["adduser", "--system", "--group", "--home", "/var/lib/icinga2", "--disabled-login", "--force-badname", "--no-create-home", "--uid", "5665", "icinga"]

ENTRYPOINT ["/entrypoint"]

COPY --from=build-icinga2 /icinga2-bin/ /

RUN ["install", "-o", "icinga", "-g", "icinga", "-d", "/data"]
RUN ["bash", "-exo", "pipefail", "-c", "for d in /etc/icinga2 /var/*/icinga2; do mkdir -p $(dirname /data-init$d); mv $d /data-init$d; ln -vs /data$d $d; done"]

EXPOSE 5665
USER icinga
CMD ["icinga2", "daemon"]


FROM icinga2 AS test-icinga2
RUN ["icinga2", "daemon", "-C"]


FROM icinga2
