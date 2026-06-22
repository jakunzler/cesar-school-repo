#!/bin/bash
# Start Fase 3 SMO lab. The default mode is the local, isolated SMO stack.
# Legacy external O-RAN SC OAM compose is still available with SMO_MODE=external.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SMO_MODE="${SMO_MODE:-local}"
SMO_PROJECT_NAME="${SMO_PROJECT_NAME:-oai-smo-lab}"
SMO_API_PORT="${SMO_API_PORT:-18080}"
SMO_COMPOSE_FILE="$PROJECT_DIR/config/smo/docker-compose.yml"

SMO_OAM_DIR="${SMO_OAM_DIR:-}"
SMO_WITH_NETWORK="${SMO_WITH_NETWORK:-0}"
SMO_WITH_TEIV="${SMO_WITH_TEIV:-0}"

die() {
    echo "ERRO: $*" >&2
    exit 1
}

compose() {
    docker compose -p "$SMO_PROJECT_NAME" -f "$SMO_COMPOSE_FILE" "$@"
}

check_port() {
    local port="$1"
    if ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]$port$"; then
        local owner
        owner="$(docker ps --format '{{.Names}} {{.Ports}}' 2>/dev/null | grep -E "0\.0\.0\.0:$port->|127\.0\.0\.1:$port->|:$port->" || true)"
        if echo "$owner" | grep -q '^smo-'; then
            return 0
        fi
        die "porta SMO_API_PORT=$port ja esta em uso. Defina SMO_API_PORT=<porta livre>."
    fi
}

external_compose_files=()
add_external_compose_file() {
    local rel="$1"
    local required="${2:-1}"
    local file="$SMO_OAM_DIR/$rel"
    if [ -f "$file" ]; then
        external_compose_files+=("-f" "$file")
    elif [ "$required" = "1" ]; then
        die "compose obrigatorio ausente: $file"
    fi
}

up_external() {
    [ -n "$SMO_OAM_DIR" ] || die "defina SMO_OAM_DIR=/path/para/o-ran-sc-oam"
    [ -d "$SMO_OAM_DIR" ] || die "SMO_OAM_DIR nao existe: $SMO_OAM_DIR"

    add_external_compose_file "infra/docker-compose.yaml" 1
    add_external_compose_file "smo/common/docker-compose.yaml" 1
    add_external_compose_file "smo/oam/docker-compose.yaml" 1
    [ "$SMO_WITH_NETWORK" = "1" ] && add_external_compose_file "network/docker-compose.yaml" 0
    [ "$SMO_WITH_TEIV" = "1" ] && add_external_compose_file "smo/teiv/docker-compose.yaml" 0

    echo "Subindo Fase 3 SMO/OAM externo"
    echo "  SMO_OAM_DIR=$SMO_OAM_DIR"
    echo "  project=$SMO_PROJECT_NAME"
    docker compose -p "$SMO_PROJECT_NAME" "${external_compose_files[@]}" up -d
}

command -v docker >/dev/null 2>&1 || die "docker nao encontrado"

case "$SMO_MODE" in
    local)
        [ -f "$SMO_COMPOSE_FILE" ] || die "compose local ausente: $SMO_COMPOSE_FILE"
        check_port "$SMO_API_PORT"
        mkdir -p "$PROJECT_DIR/logs"

        echo "Subindo Fase 3 SMO local e isolada"
        echo "  project=$SMO_PROJECT_NAME"
        echo "  API=http://127.0.0.1:$SMO_API_PORT"
        echo "  compose=$SMO_COMPOSE_FILE"
        SMO_API_PORT="$SMO_API_PORT" compose up -d --build
        echo ""
        echo "SMO local iniciado. Validar com:"
        echo "  ./scripts/test_smo_lab.sh"
        ;;
    external)
        up_external
        echo ""
        echo "SMO/OAM externo iniciado. Validar com:"
        echo "  SMO_MODE=external SMO_OAM_DIR=$SMO_OAM_DIR ./scripts/test_smo_lab.sh"
        ;;
    *)
        die "SMO_MODE invalido: $SMO_MODE (use local ou external)"
        ;;
esac

echo ""
echo "Parar com:"
echo "  ./scripts/down_smo_lab.sh"
