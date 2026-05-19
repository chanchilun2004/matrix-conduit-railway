FROM matrixconduit/matrix-conduit:latest

COPY conduit-entrypoint.sh /conduit-entrypoint.sh
RUN chmod +x /conduit-entrypoint.sh

ENTRYPOINT ["/conduit-entrypoint.sh"]
