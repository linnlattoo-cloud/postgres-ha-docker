#!/usr/bin/env bash
# PostgreSQL HA Cluster Teardown Script
# Shuts down the cluster cleanly.
# Usage:
#   ./teardown.sh            # Stops containers, preserves database volumes
#   ./teardown.sh -v         # Stops containers AND deletes volumes (clean slate)

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

WIPE_VOLUMES=false

for arg in "$@"; do
    case "${arg}" in
        -v|--volumes)
            WIPE_VOLUMES=true
            ;;
        *)
            echo "Unknown option: ${arg}"
            echo "Usage: $0 [-v|--volumes]"
            exit 1
            ;;
    esac
done

echo -e "\n${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}           Tearing Down PostgreSQL HA Cluster                 ${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}\n"

if ${WIPE_VOLUMES}; then
    log_warn "Volume wipe enabled (-v). Persistent database & etcd volumes will be DELETED."
    read -rp "Are you sure you want to delete all cluster data? [y/N]: " confirm
    if [[ "${confirm}" =~ ^[Yy]$ ]]; then
        log_info "Stopping containers and removing volumes..."
        docker compose down -v --remove-orphans
        log_ok "Cluster stopped and all data volumes removed (fresh state)."
    else
        log_info "Aborted volume wipe. Stopping containers without deleting volumes..."
        docker compose down --remove-orphans
        log_ok "Containers stopped. Persistent data preserved."
    fi
else
    log_info "Stopping containers (preserving volumes)..."
    docker compose down --remove-orphans
    log_ok "Containers stopped. Data volumes preserved."
    log_info "To also purge database volumes, run: ./teardown.sh -v"
fi

echo ""
