FROM busybox:musl AS busybox
FROM docker.io/girlbossceo/conduwuit:latest

COPY --from=busybox /bin/busybox /busybox
RUN ["/busybox", "sh", "-c", "\
  /busybox mkdir -p /bin && \
  for cmd in sh mkdir base64 echo find head cat tr grep; do \
    /busybox ln -sf /busybox /bin/$cmd; \
  done && \
  CONDUWUIT_BIN=$(/busybox find /usr /bin /opt /nix -name conduwuit -type f 2>/dev/null | /busybox head -1) && \
  /busybox echo \"Found conduwuit at: $CONDUWUIT_BIN\" && \
  /busybox ln -sf \"$CONDUWUIT_BIN\" /bin/conduwuit"]

COPY --chmod=755 conduit-entrypoint.sh /conduit-entrypoint.sh
ENTRYPOINT ["/bin/sh", "/conduit-entrypoint.sh"]
