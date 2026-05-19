#!/bin/sh
set -e

/bin/mkdir -p /var/lib/matrix-conduit

cat > /var/lib/matrix-conduit/meta-registration.yaml << YAML
id: meta
url: ${MAUTRIX_PUBLIC_URL}
as_token: ${MAUTRIX_AS_TOKEN}
hs_token: ${MAUTRIX_HS_TOKEN}
sender_localpart: metabot
rate_limited: false
namespaces:
  users:
    - exclusive: true
      regex: '@meta_.+:.*'
  aliases: []
  rooms: []
YAML

echo "[entrypoint] Registration written:"
/bin/cat /var/lib/matrix-conduit/meta-registration.yaml

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
appservice_config_files = ["/var/lib/matrix-conduit/meta-registration.yaml"]
TOML

export CONDUIT_CONFIG=/var/lib/matrix-conduit/conduit.toml
echo "[entrypoint] Starting conduit..."
exec /bin/conduit "$@"
