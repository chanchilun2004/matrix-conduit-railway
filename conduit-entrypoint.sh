#!/bin/sh
set -e

if [ -n "$META_REGISTRATION_B64" ]; then
  /bin/mkdir -p /var/lib/matrix-conduit
  /bin/echo "$META_REGISTRATION_B64" | /bin/base64 -d > /var/lib/matrix-conduit/meta-registration.yaml
  export CONDUIT_APPSERVICE_CONFIG_FILES=/var/lib/matrix-conduit/meta-registration.yaml
fi

echo "=== /nix/store ==="
/busybox ls /nix/store/ 2>/dev/null | /busybox grep conduit
exit 1
