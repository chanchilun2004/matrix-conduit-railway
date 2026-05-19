#!/bin/sh
set -e

/bin/mkdir -p /var/lib/matrix-conduit

if [ -n "$META_REGISTRATION_B64" ]; then
  CLEAN_B64=$(echo "$META_REGISTRATION_B64" | tr -d ' \n\r\t')
  echo "$CLEAN_B64" | /bin/base64 -d > /var/lib/matrix-conduit/meta-registration.yaml
  echo "[entrypoint] Registration file written:"
  /bin/cat /var/lib/matrix-conduit/meta-registration.yaml
  APPSERVICE_LINE='appservice_config_files = ["/var/lib/matrix-conduit/meta-registration.yaml"]'
else
  echo "[entrypoint] WARNING: META_REGISTRATION_B64 not set"
  APPSERVICE_LINE='appservice_config_files = []'
fi

cat > /var/lib/matrix-conduit/conduit.toml << TOML
[global]
server_name = "${CONDUIT_SERVER_NAME}"
database_backend = "${CONDUIT_DATABASE_BACKEND:-rocksdb}"
database_path = "${CONDUIT_DATABASE_PATH:-/var/lib/matrix-conduit/}"
address = "${CONDUIT_ADDRESS:-0.0.0.0}"
port = ${CONDUIT_PORT:-6167}
max_request_size = ${CONDUIT_MAX_REQUEST_SIZE:-20000000}
max_concurrent_requests = ${CONDUIT_MAX_CONCURRENT_REQUESTS:-100}
allow_registration = ${CONDUIT_ALLOW_REGISTRATION:-true}
allow_federation = ${CONDUIT_ALLOW_FEDERATION:-true}
allow_check_for_updates = ${CONDUIT_ALLOW_CHECK_FOR_UPDATES:-false}
trusted_servers = ${CONDUIT_TRUSTED_SERVERS:-["matrix.org"]}
$APPSERVICE_LINE
TOML

echo "[entrypoint] conduit.toml written:"
/bin/cat /var/lib/matrix-conduit/conduit.toml

export CONDUIT_CONFIG=/var/lib/matrix-conduit/conduit.toml
echo "[entrypoint] Starting conduit..."
exec /bin/conduit "$@"
