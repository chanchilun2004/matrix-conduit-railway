#!/bin/sh
set -e

if [ -n "$META_REGISTRATION_B64" ]; then
  mkdir -p /var/lib/matrix-conduit
  echo "$META_REGISTRATION_B64" | base64 -d > /var/lib/matrix-conduit/meta-registration.yaml
  export CONDUIT_APPSERVICE_CONFIG_FILES=/var/lib/matrix-conduit/meta-registration.yaml
fi

echo "=== Root directory ==="
/busybox ls /
echo "=== /usr/bin ==="
/busybox ls /usr/bin 2>/dev/null || echo "not found"
echo "=== /usr/local/bin ==="
/busybox ls /usr/local/bin 2>/dev/null || echo "not found"
echo "=== /srv ==="
/busybox ls /srv 2>/dev/null || echo "not found"
exit 1
