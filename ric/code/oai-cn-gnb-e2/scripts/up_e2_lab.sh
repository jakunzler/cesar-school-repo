#!/bin/bash
# Sobe laboratório completo: Core OAI + nearRT-RIC + gNB E2 + nrUE.
# Uso: ./scripts/up_e2_lab.sh
#
# Requer gNB compilado com E2: ./scripts/build_e2.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=========================================="
echo "Laboratório E2: Core + FlexRIC + gNB + UE"
echo "=========================================="
echo ""

# 1. Core
if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qE '^oai-amf$'; then
    echo "[1/4] Iniciando Core OAI..."
    "$SCRIPT_DIR/up_core.sh"
else
    echo "[1/4] Core OAI já em execução."
fi

# 2. nearRT-RIC
echo ""
echo "[2/4] Iniciando nearRT-RIC..."
"$SCRIPT_DIR/up_flexric.sh"

# 3. gNB + UE (com E2 agent)
echo ""
echo "[3/4] Iniciando gNB OAI + nrUE (E2 agent → 127.0.0.1)..."
"$SCRIPT_DIR/up_gnb_oai.sh"

# 4. Aguardar registro UE
echo ""
echo "[4/4] Aguardando UE registrar (30s)..."
sleep 30

echo ""
echo "=========================================="
echo "Laboratório E2 pronto"
echo "=========================================="
echo ""
echo "Verificar E2 setup nos logs do gNB:"
echo "  grep -iE 'E2|RIC|setup' ${OAI_LOG_DIR:-$PROJECT_DIR/logs}/gnb_oai.log"
echo ""
echo "Testar Service Models:"
echo "  ./scripts/test_e2_sm.sh cust    # MAC/RLC/PDCP/GTP (recomendado com slice 222/123)"
echo "  ./scripts/test_e2_sm.sh oran    # KPM + RC (KPM exige slice SST=1)"
echo "  ./scripts/test_e2_sm.sh all"
echo ""
echo "Parar: ./scripts/down_e2_lab.sh"
