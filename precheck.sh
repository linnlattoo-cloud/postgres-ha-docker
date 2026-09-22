#!/usr/bin/env bash
# PostgreSQL HA Environment Precheck Script
# Validates system requirements, docker availability, and port conflicts.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

echo -e "\n${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}        PostgreSQL HA Stack — Preflight Validation            ${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}\n"

ERRORS=0

# 1. Check Docker Installation
if ! command -v docker &> /dev/null; then
    log_error "Docker CLI is not installed. Please install Docker Engine or Docker Desktop."
    ((ERRORS++))
else
    log_ok "Docker CLI found: $(docker --version)"
fi

# 2. Check Docker Daemon Status
if ! docker info &> /dev/null; then
    log_error "Docker daemon is not running. Please start Docker and retry."
    ((ERRORS++))
else
    log_ok "Docker daemon is running and responsive."
fi

# 3. Check Docker Compose V2
if ! docker compose version &> /dev/null; then
    log_error "Docker Compose V2 plugin ('docker compose') is missing."
    ((ERRORS++))
else
    log_ok "Docker Compose found: $(docker compose version --short)"
fi

# 4. Check Environment File (.env)
ENV_FILE="${SCRIPT_DIR}/.env"
if [[ ! -f "${ENV_FILE}" ]]; then
    if [[ -f "${SCRIPT_DIR}/.env.example" ]]; then
        log_warn ".env file not found. Auto-generating from .env.example..."
        cp "${SCRIPT_DIR}/.env.example" "${ENV_FILE}"
        log_ok ".env created. Adjust passwords inside if deploying to shared environments."
    else
        log_error "Neither .env nor .env.example found in ${SCRIPT_DIR}."
        ((ERRORS++))
    fi
else
    log_ok "Environment file (.env) detected."
fi

# Source .env for port checks
if [[ -f "${ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    set -a && source "${ENV_FILE}" && set +a
fi

# 5. Check Port Availability
check_port() {
    local port="$1"
    local desc="$2"
    if (echo > /dev/tcp/127.0.0.1/"${port}") &>/dev/null; then
        # Check if the port is already used by our own compose stack
        local container
        container=$(docker ps --filter "publish=${port}" --format "{{.Names}}" 2>/dev/null || true)
        if [[ -n "${container}" ]]; then
            log_ok "Port ${port} (${desc}) is bound by existing container: ${container}"
        else
            log_error "Port ${port} (${desc}) is already in use by another local process!"
            ((ERRORS++))
        fi
    else
        log_ok "Port ${port} (${desc}) is free."
    fi
}

check_port "${HAPROXY_PRIMARY_PORT:-5432}" "HAProxy Primary Write"
check_port "${HAPROXY_REPLICA_PORT:-5433}" "HAProxy Read Replica"
check_port "${HAPROXY_STATS_PORT:-7070}" "HAProxy Stats Dashboard"

echo ""
if [[ "${ERRORS}" -gt 0 ]]; then
    log_error "Preflight checks encountered ${ERRORS} error(s). Aborting deployment."
    exit 1
else
    log_ok "All preflight checks passed successfully! Ready to deploy."
    echo ""
    exit 0
fi
