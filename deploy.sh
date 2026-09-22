#!/usr/bin/env bash
# PostgreSQL HA Cluster One-Click Deploy Script
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Terminal Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

# 1. Run Precheck
"${SCRIPT_DIR}/precheck.sh"

# Source environment
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
    # shellcheck disable=SC1090
    set -a && source "${SCRIPT_DIR}/.env" && set +a
fi

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}   Building & Starting PostgreSQL HA Cluster (${CLUSTER_SCOPE})   ${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

# 2. Build and start containers
log_info "Launching containers in detached mode..."
docker compose up -d --build

# 3. Wait for etcd consensus
log_info "Waiting for 3-node etcd consensus to stabilize..."
ETCD_ATTEMPTS=0
MAX_ETCD_ATTEMPTS=30
until docker compose exec -T etcd1 etcdctl endpoint health &>/dev/null || [[ ${ETCD_ATTEMPTS} -ge ${MAX_ETCD_ATTEMPTS} ]]; do
    sleep 1
    ((ETCD_ATTEMPTS++))
done

if [[ ${ETCD_ATTEMPTS} -ge ${MAX_ETCD_ATTEMPTS} ]]; then
    log_warn "etcd health check timed out. Proceeding to verify Patroni..."
else
    log_ok "etcd 3-node consensus verified healthy."
fi

# 4. Wait for Patroni cluster bootstrap & leader election
log_info "Waiting for Patroni cluster bootstrap and leader election..."
LEADER_FOUND=false
PATRONI_ATTEMPTS=0
MAX_PATRONI_ATTEMPTS=45

while [[ ${PATRONI_ATTEMPTS} -lt ${MAX_PATRONI_ATTEMPTS} ]]; do
    STATUS_OUTPUT=$(docker compose exec -T pg1 patronictl -c /etc/patroni/patroni.yml list 2>/dev/null || true)
    if echo "${STATUS_OUTPUT}" | grep -q "Leader"; then
        LEADER_FOUND=true
        break
    fi
    sleep 2
    ((PATRONI_ATTEMPTS++))
    echo -n "."
done
echo ""

if [[ "${LEADER_FOUND}" == "true" ]]; then
    log_ok "Patroni leader election complete!"
else
    log_warn "Cluster is taking longer than expected to elect a leader. Check logs: docker compose logs -f"
fi

# 5. Display Summary & Connection Info
echo -e "\n${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}          PostgreSQL HA Cluster Deployed Successfully!         ${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}\n"

echo -e "Cluster Topology:"
docker compose exec -T pg1 patronictl -c /etc/patroni/patroni.yml list || true

echo -e "\n${CYAN}Cluster Endpoints:${NC}"
echo -e "  • Primary (Read/Write) : localhost:${HAPROXY_PRIMARY_PORT:-5432}"
echo -e "  • Replicas (Read-Only) : localhost:${HAPROXY_REPLICA_PORT:-5433} (Load-balanced)"
echo -e "  • HAProxy Dashboard    : http://localhost:${HAPROXY_STATS_PORT:-7070} (User: ${HAPROXY_STATS_USER:-admin} / Pass: ${HAPROXY_STATS_PASSWORD:-admin_stats_pass_2026})"

echo -e "\n${CYAN}Quick Connect Examples:${NC}"
echo -e "  # Connect to Read/Write Primary:"
echo -e "  psql -h 127.0.0.1 -p ${HAPROXY_PRIMARY_PORT:-5432} -U ${POSTGRES_SUPERUSER:-postgres} -d postgres"
echo -e "\n  # Connect to Load-Balanced Read Replicas:"
echo -e "  psql -h 127.0.0.1 -p ${HAPROXY_REPLICA_PORT:-5433} -U ${POSTGRES_SUPERUSER:-postgres} -d postgres"

echo -e "\n${CYAN}Validation & Testing Commands:${NC}"
echo -e "  • Check cluster health : ./scripts/cluster-status.sh"

echo -e "  • View live logs       : docker compose logs -f"
echo -e "  • Teardown cluster     : ./teardown.sh"
echo ""
