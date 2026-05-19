#!/bin/sh
set -e

if [ -n "$META_REGISTRATION_B64" ]; then
  mkdir -p /var/lib/matrix-conduit
  echo "$META_REGISTRATION_B64" | base64 -d > /var/lib/matrix-conduit/meta-registration.yaml
  export CONDUIT_APPSERVICE_CONFIG_FILES=/var/lib/matrix-conduit/meta-registration.yaml
fi

exec /usr/local/bin/conduit "$@"
