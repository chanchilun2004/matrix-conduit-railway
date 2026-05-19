#!/bin/sh
set -e

if [ -n "$META_REGISTRATION_B64" ]; then
  /bin/mkdir -p /var/lib/matrix-conduit
  /bin/echo "$META_REGISTRATION_B64" | /bin/base64 -d > /var/lib/matrix-conduit/meta-registration.yaml
  export CONDUIT_APPSERVICE_CONFIG_FILES=/var/lib/matrix-conduit/meta-registration.yaml
fi

echo "[entrypoint] Checking conduit binary..."
if [ ! -f /bin/conduit ]; then
  echo "[entrypoint] ERROR: /bin/conduit missing, searching nix store..."
  /busybox find /nix/store -name conduit -type f 2>/dev/null
  exit 1
fi
echo "[entrypoint] conduit found at: $(/busybox readlink /bin/conduit)"
echo "[entrypoint] CONDUIT_SERVER_NAME=${CONDUIT_SERVER_NAME}"
echo "[entrypoint] Starting conduit..."
exec /bin/conduit "$@"
