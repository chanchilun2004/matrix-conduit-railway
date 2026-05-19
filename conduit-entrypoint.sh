#!/bin/sh
set -e

if [ -n "$META_REGISTRATION_B64" ]; then
  mkdir -p /var/lib/matrix-conduit
  echo "$META_REGISTRATION_B64" | base64 -d > /var/lib/matrix-conduit/meta-registration.yaml
  export CONDUIT_APPSERVICE_CONFIG_FILES=/var/lib/matrix-conduit/meta-registration.yaml
fi

# Find conduit binary
CONDUIT_BIN=""
for p in /srv/conduit /conduit /usr/bin/conduit /usr/local/bin/conduit /app/conduit /bin/conduit; do
  if [ -f "$p" ]; then
    CONDUIT_BIN="$p"
    break
  fi
done

if [ -z "$CONDUIT_BIN" ]; then
  echo "Searching for conduit binary..."
  find / -name "conduit" -type f 2>/dev/null | head -5
  exit 1
fi

exec "$CONDUIT_BIN" "$@"
