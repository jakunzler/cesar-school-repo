#!/bin/bash
# Stop Fase 3 SMO lab. Does not touch Fase 1/2.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SMO_MODE="${SMO_MODE:-local}"
SMO_PROJECT_NAME="${SMO_PROJECT_NAME:-oai-smo-lab}"
SMO_COMPOSE_FILE="$PROJECT_DIR/config/smo/docker-compose.yml"

SMO_OAM_DIR="${SMO_OAM_DIR:-}"
SMO_WITH_NETWORK="${SMO_WITH_NETWORK:-0}"
SMO_WITH_TEIV="${SMO_WITH_TEIV:-0}"

die() {
    echo "ERRO: $*" >&2
    exit 1
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

case "$SMO_MODE" in
    local)
        docker compose -p "$SMO_PROJECT_NAME" -f "$SMO_COMPOSE_FILE" down
        ;;
    external)
        [ -n "$SMO_OAM_DIR" ] || die "defina SMO_OAM_DIR=/path/para/o-ran-sc-oam"
        [ -d "$SMO_OAM_DIR" ] || die "SMO_OAM_DIR nao existe: $SMO_OAM_DIR"
        add_external_compose_file "infra/docker-compose.yaml" 1
        add_external_compose_file "smo/common/docker-compose.yaml" 1
        add_external_compose_file "smo/oam/docker-compose.yaml" 1
        [ "$SMO_WITH_NETWORK" = "1" ] && add_external_compose_file "network/docker-compose.yaml" 0
        [ "$SMO_WITH_TEIV" = "1" ] && add_external_compose_file "smo/teiv/docker-compose.yaml" 0
        docker compose -p "$SMO_PROJECT_NAME" "${external_compose_files[@]}" down
        ;;
    *)
        die "SMO_MODE invalido: $SMO_MODE (use local ou external)"
        ;;
esac

echo "Fase 3 SMO parada (mode=$SMO_MODE, project=$SMO_PROJECT_NAME)."
