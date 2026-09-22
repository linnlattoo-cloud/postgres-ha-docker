#!/usr/bin/env bash
# Patroni Node Entrypoint
set -eo pipefail

export CLUSTER_SCOPE="${CLUSTER_SCOPE:-postgres-cluster}"
export PATRONI_NAME="${PATRONI_NAME:-$(hostname)}"
export PATRONI_ETCD3_HOSTS="${PATRONI_ETCD3_HOSTS:-etcd1:2379,etcd2:2379,etcd3:2379}"
export POSTGRES_SUPERUSER="${POSTGRES_SUPERUSER:-postgres}"
export POSTGRES_SUPERUSER_PASSWORD="${POSTGRES_SUPERUSER_PASSWORD:-postgres_secure_password_2026}"
export POSTGRES_REPLICATION_USER="${POSTGRES_REPLICATION_USER:-replicator}"
export POSTGRES_REPLICATION_PASSWORD="${POSTGRES_REPLICATION_PASSWORD:-replicator_secure_password_2026}"
export PATRONI_TTL="${PATRONI_TTL:-30}"
export PATRONI_LOOP_WAIT="${PATRONI_LOOP_WAIT:-10}"
export PATRONI_RETRY_TIMEOUT="${PATRONI_RETRY_TIMEOUT:-10}"
export PATRONI_MAX_CONNECTIONS="${PATRONI_MAX_CONNECTIONS:-200}"
export PATRONI_SHARED_BUFFERS="${PATRONI_SHARED_BUFFERS:-256MB}"

echo "[patroni-init] Initializing node '${PATRONI_NAME}' for cluster '${CLUSTER_SCOPE}'..."

# Render configuration template using Python
python3 - <<'EOF'
import os
import re

template_file = "/etc/patroni/patroni.yml.template"
output_file = "/etc/patroni/patroni.yml"

with open(template_file, "r") as f:
    content = f.read()

# Replace ${VAR} with environment variable or empty string
def replace_env(match):
    var_name = match.group(1)
    return os.environ.get(var_name, "")

rendered = re.sub(r'\$\{([A-Za-z0-9_]+)\}', replace_env, content)

with open(output_file, "w") as f:
    f.write(rendered)
EOF

# Ensure required runtime directories and permissions
mkdir -p /var/lib/postgresql/data /var/run/postgresql /etc/patroni
chown -R postgres:postgres /var/lib/postgresql /var/run/postgresql /etc/patroni
chmod 700 /var/lib/postgresql/data
chmod 775 /var/run/postgresql
chmod 640 /etc/patroni/patroni.yml

# Setup pgpass for internal operations
cat > /tmp/pgpass <<EOF
*:*:*:*:${POSTGRES_SUPERUSER_PASSWORD}
*:*:*:${POSTGRES_REPLICATION_USER}:${POSTGRES_REPLICATION_PASSWORD}
EOF
chown postgres:postgres /tmp/pgpass
chmod 600 /tmp/pgpass

echo "[patroni-init] Configuration generated. Starting Patroni service..."
exec gosu postgres patroni /etc/patroni/patroni.yml
