#!/bin/sh
set -e

if [ -n "$META_REGISTRATION_B64" ]; then
  /busybox mkdir -p /var/lib/matrix-conduit
  /busybox echo "$META_REGISTRATION_B64" | /busybox base64 -d > /var/lib/matrix-conduit/meta-registration.yaml
  export CONDUIT_APPSERVICE_CONFIG_FILES=/var/lib/matrix-conduit/meta-registration.yaml
fi

echo "=== /nix ==="
/busybox ls /nix 2>/dev/null || echo "no /nix"
echo "=== /nix/var/nix/profiles ==="
/busybox ls /nix/var/nix/profiles 2>/dev/null || echo "not found"
echo "=== bin ==="
/busybox ls /bin 2>/dev/null || echo "no /bin"
exit 1
