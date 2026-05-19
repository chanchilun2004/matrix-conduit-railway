FROM busybox:musl AS busybox
FROM matrixconduit/matrix-conduit:latest
COPY --from=busybox /bin/busybox /busybox
RUN ["/busybox", "sh", "-c", "/busybox mkdir -p /bin && for cmd in sh mkdir base64 echo find head; do /busybox ln -sf /busybox /bin/$cmd; done && CONDUIT_BIN=$(/busybox find /nix/store -name conduit -type f 2>/dev/null | /busybox head -1) && /busybox echo \"Found conduit at: $CONDUIT_BIN\" && /busybox ln -sf \"$CONDUIT_BIN\" /bin/conduit"]
COPY --chmod=755 conduit-entrypoint.sh /conduit-entrypoint.sh
ENTRYPOINT ["/bin/sh", "/conduit-entrypoint.sh"]
