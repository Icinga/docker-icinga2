##
## We are using many RUN blocks in order to make development easier
## They will replaced with minimal RUN blocks before release
##
ARG BUILD_BASE=ubuntu:bionic

FROM $BUILD_BASE

ENV \
  TERM=xterm \
  DEBIAN_FRONTEND=noninteractive \
  APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn

RUN apt-get update \
  && apt-get upgrade -y 

RUN apt-get install -y apt-file ; apt-file update

RUN apt-file search lsb_release
RUN apt-file search lsb-release
RUN apt-cache search lsb-release

RUN apt-get install -y curl wget gnupg2 lsb-release

RUN curl -LsS https://packages.icinga.com/icinga.key | apt-key add -

RUN DIST="$(lsb_release -c | awk '{print $2}')"; \
    echo "deb http://packages.icinga.com/ubuntu icinga-${DIST} main" >/etc/apt/sources.list.d/icinga.list

RUN apt-get update

RUN apt-get install -y --no-install-recommends icinga2-bin icinga2-common icinga2-ido-mysql monitoring-plugins

RUN rm -fr /var/lib/apt/lists/*

RUN mkdir /run/icinga2 && chown nagios. /run/icinga2

VOLUME /var/lib/icinga2

ENTRYPOINT /usr/lib/x86_64-linux-gnu/icinga2/sbin/icinga2 --no-stack-rlimit daemon

EXPOSE 5665
