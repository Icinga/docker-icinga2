# Icinga 2 Docker image | (c) 2020 Icinga GmbH | GPLv2+

FROM icinga/icinga2-deps

COPY icinga2-bin/ /

RUN ["install", "-o", "icinga", "-g", "icinga", "-d", "/data"]
VOLUME ["/data"]

RUN ["bash", "-exo", "pipefail", "-c", "for d in /etc/icinga2 /var/*/icinga2; do mkdir -p $(dirname /data-init$d); mv $d /data-init$d; ln -vs /data$d $d; done"]

USER icinga
CMD ["icinga2", "daemon"]
