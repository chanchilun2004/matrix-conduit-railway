#!/bin/sh
set -e

DATA=/data
mkdir -p "$DATA/media_store"

# Write appservice registration
cat > "$DATA/meta-registration.yaml" << YAML
id: meta
url: ${MAUTRIX_PUBLIC_URL}
as_token: ${MAUTRIX_AS_TOKEN}
hs_token: ${MAUTRIX_HS_TOKEN}
sender_localpart: metabot
rate_limited: false
namespaces:
  users:
    - exclusive: true
      regex: "@meta_.+:.*"
  aliases: []
  rooms: []
YAML

echo "[entrypoint] Registration written"

# Generate homeserver.yaml using Python
python3 << 'PYEOF'
import os, secrets, urllib.parse

server_name = os.environ['CONDUIT_SERVER_NAME']

# Load or generate stable secrets
secrets_file = '/data/.secrets'
config_secrets = {}
if os.path.exists(secrets_file):
    with open(secrets_file) as f:
        for line in f:
            k, _, v = line.strip().partition('=')
            config_secrets[k] = v

changed = False
for key in ('MACAROON', 'REG_SECRET', 'FORM_SECRET'):
    if key not in config_secrets:
        config_secrets[key] = secrets.token_hex(32)
        changed = True

if changed:
    with open(secrets_file, 'w') as f:
        for k, v in config_secrets.items():
            f.write(f'{k}={v}\n')

# Database config: PostgreSQL if DATABASE_URL is set, else SQLite
db_url = os.environ.get('DATABASE_URL', '')
if db_url:
    u = urllib.parse.urlparse(db_url)
    db_config = f"""\
database:
  name: psycopg2
  args:
    user: {u.username!r}
    password: {u.password!r}
    database: {u.path.lstrip('/') !r}
    host: {u.hostname!r}
    port: {u.port or 5432}
    cp_min: 5
    cp_max: 10
"""
else:
    db_config = """\
database:
  name: sqlite3
  args:
    database: /data/homeserver.db
    cp_min: 1
    cp_max: 1
"""

log_config = """\
version: 1
formatters:
  precise:
    format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(request)s - %(message)s'
handlers:
  console:
    class: logging.StreamHandler
    formatter: precise
loggers:
  synapse.storage.SQL:
    level: WARNING
root:
  level: INFO
  handlers: [console]
disable_existing_loggers: false
"""
with open('/data/log.config', 'w') as f:
    f.write(log_config)

homeserver_yaml = f"""\
server_name: {server_name!r}
pid_file: /data/homeserver.pid

listeners:
  - port: 6167
    tls: false
    type: http
    x_forwarded: true
    bind_addresses: ['0.0.0.0']
    resources:
      - names: [client, federation]
        compress: false

{db_config}
log_config: /data/log.config
media_store_path: /data/media_store
registration_shared_secret: {config_secrets['REG_SECRET']!r}
report_stats: false
macaroon_secret_key: {config_secrets['MACAROON']!r}
form_secret: {config_secrets['FORM_SECRET']!r}
signing_key_path: /data/{server_name}.signing.key

trusted_key_servers:
  - server_name: "matrix.org"
suppress_key_server_warning: true

app_service_config_files:
  - /data/meta-registration.yaml

allow_registration: true
enable_registration_without_verification: true
"""

with open('/data/homeserver.yaml', 'w') as f:
    f.write(homeserver_yaml)

print('[entrypoint] homeserver.yaml written (db=' + ('postgres' if db_url else 'sqlite') + ')')
PYEOF

# Generate signing key on first boot
SIGNING_KEY="/data/${CONDUIT_SERVER_NAME}.signing.key"
if [ ! -f "$SIGNING_KEY" ]; then
    echo "[entrypoint] Generating signing key..."
    python3 -m synapse.app.homeserver \
        --config-path "$DATA/homeserver.yaml" \
        --generate-keys
fi

echo "[entrypoint] Starting Synapse on port 6167..."
exec python3 -m synapse.app.homeserver \
    --config-path "/data/homeserver.yaml"