#!/bin/bash
# Validate/preflight Fase 3 SMO lab.

set -euo pipefail

MODE="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SMO_MODE="${SMO_MODE:-local}"
SMO_PROJECT_NAME="${SMO_PROJECT_NAME:-oai-smo-lab}"
SMO_API_PORT="${SMO_API_PORT:-18080}"
SMO_API_URL="${SMO_API_URL:-http://127.0.0.1:$SMO_API_PORT}"
SMO_COMPOSE_FILE="$PROJECT_DIR/config/smo/docker-compose.yml"

SMO_OAM_DIR="${SMO_OAM_DIR:-}"
SMO_WITH_NETWORK="${SMO_WITH_NETWORK:-0}"
SMO_WITH_TEIV="${SMO_WITH_TEIV:-0}"

die() {
    echo "ERRO: $*" >&2
    exit 1
}

get_json() {
    python3 - "$1" <<'PY'
import json
import sys
import urllib.request

url = sys.argv[1]
with urllib.request.urlopen(url, timeout=5) as response:
    print(json.dumps(json.loads(response.read().decode("utf-8")), indent=2, sort_keys=True))
PY
}

post_json() {
    python3 - "$1" "$2" <<'PY'
import json
import sys
import urllib.request

url = sys.argv[1]
payload = json.loads(sys.argv[2])
request = urllib.request.Request(
    url,
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, timeout=5) as response:
    print(json.dumps(json.loads(response.read().decode("utf-8")), indent=2, sort_keys=True))
PY
}

test_local_preflight() {
    echo "=== Preflight Fase 3 local ==="
    command -v docker >/dev/null 2>&1 || die "docker nao encontrado"
    command -v python3 >/dev/null 2>&1 || die "python3 nao encontrado"
    [ -f "$SMO_COMPOSE_FILE" ] || die "compose local ausente: $SMO_COMPOSE_FILE"

    echo "  OK docker"
    echo "  OK python3"
    echo "  OK $SMO_COMPOSE_FILE"

    python3 -m py_compile "$PROJECT_DIR"/config/smo/smo_lab/*.py
    echo "  OK sintaxe Python SMO"

    docker compose -p "$SMO_PROJECT_NAME" -f "$SMO_COMPOSE_FILE" config >/dev/null
    echo "  OK docker compose config"

    echo ""
    echo "Portas:"
    if ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]$SMO_API_PORT$"; then
        echo "  SMO_API_PORT=$SMO_API_PORT em uso"
    else
        echo "  SMO_API_PORT=$SMO_API_PORT livre"
    fi
}

test_local_runtime() {
    echo "=== Containers SMO local ==="
    docker compose -p "$SMO_PROJECT_NAME" -f "$SMO_COMPOSE_FILE" ps

    echo ""
    echo "=== Health API ==="
    get_json "$SMO_API_URL/health"

    echo ""
    echo "=== Ingestao O1/VES/KPM de teste ==="
    post_json "$SMO_API_URL/o1/v1/nodes" '{"node_id":"odu-test-001","node_type":"O-DU","status":"unlocked","interface":"O1"}' >/dev/null
    post_json "$SMO_API_URL/ves/v7/events" '{"domain":"fault","eventType":"TEST_EVENT","sourceName":"odu-test-001","severity":"NORMAL"}' >/dev/null
    post_json "$SMO_API_URL/metrics/kpm" '{"source":"test_smo_lab","metrics":[{"metric":"DRB.UEThpDl","value":12.5,"unit":"kbps"},{"metric":"RRU.PrbTotUl","value":2,"unit":"%"}]}' >/dev/null

    echo ""
    echo "=== Topologia ==="
    get_json "$SMO_API_URL/topology"

    echo ""
    echo "=== Metricas KPM armazenadas ==="
    get_json "$SMO_API_URL/metrics/kpm?limit=10"

    echo ""
    echo "=== Workflow IA/ML ==="
    get_json "$SMO_API_URL/ml/runs?limit=5"
}

test_external() {
    [ -n "$SMO_OAM_DIR" ] || die "defina SMO_OAM_DIR=/path/para/o-ran-sc-oam"
    [ -d "$SMO_OAM_DIR" ] || die "SMO_OAM_DIR nao existe: $SMO_OAM_DIR"

    echo "=== Preflight arquivos SMO/OAM externo ==="
    for rel in infra/docker-compose.yaml smo/common/docker-compose.yaml smo/oam/docker-compose.yaml; do
        if [ -f "$SMO_OAM_DIR/$rel" ]; then
            echo "  OK  $rel"
        else
            die "FALTA $rel"
        fi
    done
    [ -f "$SMO_OAM_DIR/network/docker-compose.yaml" ] && echo "  OK  network/docker-compose.yaml" || echo "  opcional ausente network/docker-compose.yaml"
    [ -f "$SMO_OAM_DIR/smo/teiv/docker-compose.yaml" ] && echo "  OK  smo/teiv/docker-compose.yaml" || echo "  opcional ausente smo/teiv/docker-compose.yaml"

    if [ "$MODE" != "--preflight" ]; then
        echo ""
        echo "Use o modo externo para listagem completa:"
        echo "  docker compose -p $SMO_PROJECT_NAME -f <compose files> ps"
    fi
}

echo "=========================================="
echo "Teste Fase 3 SMO"
echo "=========================================="
echo "mode=$SMO_MODE"

case "$SMO_MODE" in
    local)
        test_local_preflight
        [ "$MODE" = "--preflight" ] && exit 0
        test_local_runtime
        ;;
    external)
        test_external
        ;;
    *)
        die "SMO_MODE invalido: $SMO_MODE (use local ou external)"
        ;;
esac

echo ""
echo "Teste Fase 3 concluido."
