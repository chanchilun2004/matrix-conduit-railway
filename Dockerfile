FROM matrixdotorg/synapse:latest
COPY --chmod=755 conduit-entrypoint.sh /synapse-entrypoint.sh
ENTRYPOINT ["/synapse-entrypoint.sh"]