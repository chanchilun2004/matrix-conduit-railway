FROM busybox:musl AS busybox

FROM matrixconduit/matrix-conduit:latest
COPY --from=busybox /bin/busybox /busybox
RUN ["/busybox", "sh", "-c", "/busybox mkdir -p /bin && /busybox ln -sf /busybox /bin/sh && /busybox ln -sf /busybox /bin/mkdir && /busybox ln -sf /busybox /bin/base64 && /busybox ln -sf /busybox /bin/echo"]
COPY --chmod=755 conduit-entrypoint.sh /conduit-entrypoint.sh
ENTRYPOINT ["/bin/sh", "/conduit-entrypoint.sh"]
