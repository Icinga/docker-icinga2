FROM icinga/icinga2-deps

COPY --chown=icinga:icinga icinga2-bin/ /

USER icinga
CMD ["icinga2", "daemon"]
