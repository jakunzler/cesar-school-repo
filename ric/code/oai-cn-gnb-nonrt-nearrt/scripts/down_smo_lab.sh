#!/bin/bash
# Stop Fase 3 SMO/OAM compose stack. Does not touch Fase 1/2 scripts.

set -euo pipefail

SMO_OAM_DIR="${SMO_OAM_DIR:-}"
SMO_PROJECT_NAME="${SMO_PROJECT_NAME:-oai-smo-lab}"
SMO_WITH_NETWORK="${SMO_WITH_NETWORK:-0}"
SMO_WITH_TEIV="${SMO_WITH_TEIV:-0}"

die() {
    echo "ERRO: $*" >&2
    exit 1
}

compose_files=()

add_compose_file() {
    local rel="$1"
    local required="${2:-1}"
    local file="$SMO_OAM_DIR/$rel"
    if [ -f "$file" ]; then
        compose_files+=("-f" "$file")
    elif [ "$required" = "1" ]; then
        die "compose obrigatorio ausente: $file"
    fi
}

[ -n "$SMO_OAM_DIR" ] || die "defina SMO_OAM_DIR=/path/para/o-ran-sc-oam"
[ -d "$SMO_OAM_DIR" ] || die "SMO_OAM_DIR nao existe: $SMO_OAM_DIR"

add_compose_file "infra/docker-compose.yaml" 1
add_compose_file "smo/common/docker-compose.yaml" 1
add_compose_file "smo/oam/docker-compose.yaml" 1

if [ "$SMO_WITH_NETWORK" = "1" ]; then
    add_compose_file "network/docker-compose.yaml" 0
fi

if [ "$SMO_WITH_TEIV" = "1" ]; then
    add_compose_file "smo/teiv/docker-compose.yaml" 0
fi

docker compose -p "$SMO_PROJECT_NAME" "${compose_files[@]}" down

echo "Fase 3 SMO/OAM parada (project=$SMO_PROJECT_NAME)."

