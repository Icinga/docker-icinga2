# Icinga 2 - Docker image

This image integrates [Icinga 2] into your [Docker] environment.

## Usage

```bash
docker network create icinga

# CA
docker run --rm \
	-h icinga-master \
	-v icinga-master:/data \
	-e ICINGA_MASTER=1 \
	icinga/icinga2 \
	cat /var/lib/icinga2/certs/ca.crt > icinga-ca.crt

# Ticket
docker run --rm \
	-h icinga-master \
	-v icinga-master:/data \
	-e ICINGA_MASTER=1 \
	icinga/icinga2 \
	icinga2 daemon -C
docker run --rm \
	-h icinga-master \
	-v icinga-master:/data \
	-e ICINGA_MASTER=1 \
	icinga/icinga2 \
	icinga2 pki ticket --cn icinga-agent > icinga-agent.ticket

# Master
docker run --rm -d \
	--network icinga \
	--name icinga-master \
	-h icinga-master \
	-p 5665:5665 \
	-v icinga-master:/data \
	-e ICINGA_MASTER=1 \
	icinga/icinga2

# Agent
docker run --rm -d \
	--network icinga \
	-h icinga-agent \
	-v icinga-agent:/data \
	-e ICINGA_ZONE=icinga-agent \
	-e ICINGA_ENDPOINT=icinga-master,icinga-master,5665 \
	-e ICINGA_CACERT="$(< icinga-ca.crt)" \
	-e ICINGA_TICKET="$(< icinga-agent.ticket)" \
	icinga/icinga2
```

The container may listen on port 5665 and expects
a volume on `/data` and a specific persistent hostname.
To configure it, do one of the following:

* Run the node wizard as usual. It will store all data in `/data`.
  Hint: `docker run --rm -it -h icinga-master -v icinga-master:/data icinga/icinga2 icinga2 node wizard`
* Provide configuration files, certificates, etc.
  in `/data/etc/icinga2` and `/data/var/...` by yourself.
  Consult the [Icinga 2 configuration documentation]
  on which configuration files there are.
* Provide environment variables as shown above.

### Environment variables

Most of the following variables correspond to
`icinga2 node setup` CLI parameters.
If any of these is present and `icinga2 node setup`
has not been run yet, it will run.
Consult the [node command documentation] on what are which parameters for.

Regular variables:

 Variable                                                 | Node setup CLI
 ---------------------------------------------------------|--------------------
 `ICINGA_ACCEPT_COMMANDS=1`                               | `--accept-commands`
 `ICINGA_ACCEPT_CONFIG=1`                                 | `--accept-config`
 `ICINGA_DISABLE_CONFD=1`                                 | `--disable-confd`
 `ICINGA_MASTER=1`                                        | `--master`
 `ICINGA_CN=icinga-master`                                | `--cn icinga-master`
 `ICINGA_ENDPOINT=icinga-master,2001:db8::192.0.2.9,5665` | `--endpoint icinga-master,2001:db8::192.0.2.9,5665`
 `ICINGA_GLOBAL_ZONES=global-config`                      | `--global_zones global-config`
 `ICINGA_LISTEN=::,5665`                                  | `--listen ::,5665`
 `ICINGA_PARENT_HOST=2001:db8::192.0.2.9,5665`            | `--parent_host 2001:db8::192.0.2.9,5665`
 `ICINGA_PARENT_ZONE=master`                              | `--parent_zone master`
 `ICINGA_TICKET=0123456789abcdef0123456789abcdef01234567` | `--ticket 0123456789abcdef0123456789abcdef01234567`
 `ICINGA_ZONE=master`                                     | `--zone master`

Special variables:

* `ICINGA_TRUSTEDCERT`'s value is written to a temporary file
  which is passed to `icinga2 node setup` via `--trustedcert`.
* `ICINGA_CACERT`'s value is written to `/var/lib/icinga2/certs/ca.crt`.

[Icinga 2]: https://github.com/Icinga/icinga2
[Docker]: https://www.docker.com
[Icinga 2 configuration documentation]: https://icinga.com/docs/icinga2/latest/doc/04-configuration/
[node command documentation]: https://icinga.com/docs/icinga2/latest/doc/11-cli-commands/#cli-command-node
