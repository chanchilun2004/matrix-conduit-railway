#!/bin/sh
set -e

DATA=/data
mkdir -p "$DATA/media_store"

# Write mautrix-meta appservice registration
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

# Write KOL Agent Tool appservice registration (optional — only if env vars set)
KOL_APP_REGISTRATION=""
if [ -n "$KOL_APP_URL" ] && [ -n "$KOL_AS_TOKEN" ] && [ -n "$KOL_HS_TOKEN" ]; then
    cat > "$DATA/kol-registration.yaml" << YAML
id: kolagent
url: ${KOL_APP_URL}/api/matrix/webhook
as_token: ${KOL_AS_TOKEN}
hs_token: ${KOL_HS_TOKEN}
sender_localpart: kolagent
rate_limited: false
namespaces:
  users:
    - exclusive: false
      regex: "@meta_.+:.*"
  aliases:
    - exclusive: false
      regex: "#ig_.+:.*"
  rooms: []
YAML
    KOL_APP_REGISTRATION="  - /data/kol-registration.yaml"
    echo "[entrypoint] KOL Agent appservice registration written"
fi

echo "[entrypoint] Registration written"

# Generate homeserver.yaml using Python
python3 << 'PYEOF'
import os, secrets, urllib.parse

server_name = os.environ['CONDUIT_SERVER_NAME']
kol_reg_line = "  - /data/kol-registration.yaml" if (
    os.environ.get('KOL_APP_URL') and os.environ.get('KOL_AS_TOKEN') and os.environ.get('KOL_HS_TOKEN')
) else ""

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

# Database config
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
{kol_reg_line}

allow_registration: false
enable_registration_without_verification: false
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

echo "[entrypoint] Starting Synapse in background to create bot user..."
python3 -m synapse.app.homeserver --config-path "/data/homeserver.yaml" &
SYNAPSE_PID=$!

# Wait for Synapse to be ready
echo "[entrypoint] Waiting for Synapse to accept connections..."
for i in $(seq 1 30); do
    if python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:6167/_matrix/client/versions')" 2>/dev/null; then
        echo "[entrypoint] Synapse is ready"
        break
    fi
    sleep 2
done

# Create kolbot admin user if not exists, print access token
BOT_TOKEN_FILE="$DATA/.kolbot_token"
if [ ! -f "$BOT_TOKEN_FILE" ]; then
    echo "[entrypoint] Creating kolbot admin user..."
    register_new_matrix_user \
        -c "$DATA/homeserver.yaml" \
        -u kolbot \
        -p "KolBot2026!Matrix" \
        --admin \
        http://localhost:6167 2>&1 || echo "[entrypoint] Note: user may already exist"

    # Login to get access token
    python3 << 'PYEOF'
import urllib.request, json, os

data = json.dumps({
    "type": "m.login.password",
    "user": "kolbot",
    "password": "KolBot2026!Matrix"
}).encode()
req = urllib.request.Request(
    "http://localhost:6167/_matrix/client/v3/login",
    data=data,
    headers={"Content-Type": "application/json"}
)
try:
    resp = json.loads(urllib.request.urlopen(req).read())
    token = resp.get("access_token", "")
    user_id = resp.get("user_id", "")
    with open("/data/.kolbot_token", "w") as f:
        f.write(token)
    print(f"[entrypoint] ============================================")
    print(f"[entrypoint] KOLBOT USER ID:    {user_id}")
    print(f"[entrypoint] MATRIX_ACCESS_TOKEN={token}")
    print(f"[entrypoint] ============================================")
except Exception as e:
    print(f"[entrypoint] Login failed: {e}")
PYEOF
else
    TOKEN=$(cat "$BOT_TOKEN_FILE")
    TOKEN_PREFIX=$(printf '%s' "$TOKEN" | cut -c1-20)
    echo "[entrypoint] ============================================"
    echo "[entrypoint] kolbot token already exists: ${TOKEN_PREFIX}..."
    echo "[entrypoint] MATRIX_ACCESS_TOKEN=$(cat $BOT_TOKEN_FILE)"
    echo "[entrypoint] ============================================"
fi

echo "[entrypoint] Bringing Synapse to foreground..."
wait $SYNAPSE_PID