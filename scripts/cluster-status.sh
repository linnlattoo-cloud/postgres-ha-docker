#!/usr/bin/env bash
# PostgreSQL HA Cluster Status Checker
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${SCRIPT_DIR}"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "\n${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}              PostgreSQL HA Cluster Health Report             ${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}\n"

# 1. Container Status
echo -e "${CYAN}--- [1/3] Docker Services ---${NC}"
docker compose ps
echo ""

# 2. etcd Cluster Health
echo -e "${CYAN}--- [2/3] etcd3 Quorum & Members ---${NC}"
docker compose exec -T etcd1 etcdctl \
  --endpoints=http://etcd1:2379,http://etcd2:2379,http://etcd3:2379 \
  endpoint health 2>/dev/null || echo "Unable to query etcd health"
echo ""
docker compose exec -T etcd1 etcdctl \
  --endpoints=http://etcd1:2379,http://etcd2:2379,http://etcd3:2379 \
  member list -w table 2>/dev/null || true
echo ""

# 3. Patroni Cluster Topology
echo -e "${CYAN}--- [3/3] Patroni DCS & PostgreSQL Replication ---${NC}"
docker compose exec -T pg1 patronictl -c /etc/patroni/patroni.yml list 2>/dev/null || \
docker compose exec -T pg2 patronictl -c /etc/patroni/patroni.yml list 2>/dev/null || \
docker compose exec -T pg3 patronictl -c /etc/patroni/patroni.yml list 2>/dev/null || \
echo "No active Patroni node reachable."

echo -e "\n${GREEN}Check completed.${NC}\n"
