# Icinga 2 Docker image | (c) 2020 Icinga GmbH | GPLv2+

FROM icinga/icinga2-builder

COPY action.bash compile.bash Dockerfile /

CMD ["/action.bash"]
