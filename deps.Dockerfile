FROM debian:buster-slim

RUN ["/bin/bash", "-exo", "pipefail", "-c", "export DEBIAN_FRONTEND=noninteractive; apt-get update; apt-get install --no-install-{recommends,suggests} -y libboost-{context,coroutine,date-time,filesystem,program-options,regex,system,thread}1.67 libedit2 libmariadb3 libpq5 libssl1.1 mailutils monitoring-plugins postfix; apt-get clean; rm -vrf /var/lib/apt/lists/*"]

RUN ["adduser", "--system", "--group", "--home", "/var/lib/icinga2", "--disabled-login", "--force-badname", "--no-create-home", "icinga"]
