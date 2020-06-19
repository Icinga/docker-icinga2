FROM icinga/icinga2-builder

COPY action.bash Dockerfile /

CMD ["/action.bash"]
