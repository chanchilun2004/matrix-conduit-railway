FROM busybox:musl AS busybox

FROM matrixconduit/matrix-conduit:latest
COPY --from=busybox /bin/busybox /busybox
COPY --chmod=755 conduit-entrypoint.sh /conduit-entrypoint.sh
ENTRYPOINT ["/busybox", "sh", "/conduit-entrypoint.sh"]
