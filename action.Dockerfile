FROM icinga/icinga2-builder

COPY action.bash compile.bash Dockerfile /

CMD ["/action.bash"]
