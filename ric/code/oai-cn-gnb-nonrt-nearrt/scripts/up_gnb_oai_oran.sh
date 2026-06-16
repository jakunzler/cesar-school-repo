#!/bin/bash
# Inicia gNB + nrUE com E2 agent O-RAN SC (porta 36422).
# Uso: ./scripts/up_gnb_oai_oran.sh
# Requer: ./scripts/build_e2_oran_sc.sh e ./scripts/up_oran_ric.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OAI_DIR="$PROJECT_DIR/openairinterface5g"
ORAN_BIN_DIR="$OAI_DIR/cmake_targets/ran_build/build-oran-sc"
BUILD_DIR="$ORAN_BIN_DIR"
LOG_DIR="${OAI_LOG_DIR:-$PROJECT_DIR/logs}"
FLEXRIC_LIB="${FLEXRIC_LIB_DIR:-$PROJECT_DIR/flexric-lib}"
[[ "$FLEXRIC_LIB" == */ ]] || FLEXRIC_LIB="${FLEXRIC_LIB}/"
GNB_BIN="$BUILD_DIR/nr-softmodem-oran-sc"
UE_BIN="$BUILD_DIR/nr-uesoftmodem"
GNB_LOG="$LOG_DIR/gnb_oai_oran.log"
UE_LOG="$LOG_DIR/ue_oai_oran.log"
E2_PORT="${ORAN_E2_HOST_PORT:-36422}"
E2_ADDR="${ORAN_E2_ADDR:-10.0.2.10}"

E2_SM_ARGS=()
if [ -d "$FLEXRIC_LIB" ] && [ -f "$FLEXRIC_LIB/libkpm_sm.so" ]; then
    E2_SM_ARGS=(--e2_agent.sm_dir "$FLEXRIC_LIB")
fi

echo "=========================================="
echo "gNB OAI + nrUE — E2 O-RAN SC (:$E2_PORT)"
echo "=========================================="

if [ ! -x "$GNB_BIN" ]; then
    echo "ERRO: $GNB_BIN não encontrado. Execute: ./scripts/build_e2_oran_sc.sh"
    exit 1
fi

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q ric_e2term; then
    echo "ERRO: ric_e2term não está rodando. Execute: ./scripts/up_oran_ric.sh"
    exit 1
fi

if pgrep -x "nearRT-RIC" >/dev/null 2>&1; then
    echo "ERRO: FlexRIC em execução — pare com ./scripts/down_flexric.sh"
    exit 1
fi

if ! ip -4 addr show demo-oai 2>/dev/null | grep -q "192.168.70.129"; then
    if ip link show demo-oai >/dev/null 2>&1; then
        sudo ip addr add 192.168.70.129/24 dev demo-oai 2>/dev/null || true
    else
        echo "ERRO: Core não iniciado. Execute: ./scripts/up_core.sh"
        exit 1
    fi
fi

mkdir -p "$LOG_DIR"
sudo pkill -f "nr-softmodem" 2>/dev/null || true
sudo pkill -f "nr-uesoftmodem" 2>/dev/null || true
sleep 2

cd "$BUILD_DIR"
echo "Iniciando gNB (E2 → $E2_ADDR:$E2_PORT)..."
sudo nohup ./nr-softmodem-oran-sc -O "$OAI_DIR/scripts/gnb.conf" \
    --gNBs.[0].min_rxtxtime 6 \
    --rfsim \
    --e2_agent.near_ric_ip_addr "$E2_ADDR" \
    "${E2_SM_ARGS[@]}" \
    > "$GNB_LOG" 2>&1 &
echo "  gNB PID: $! (log: $GNB_LOG)"

sleep 10
echo "Iniciando nrUE..."
sudo nohup ./nr-uesoftmodem -O "$OAI_DIR/scripts/ue.conf" \
    --rfsim -r 106 --numerology 1 --band 78 -C 3619200000 --ssb 516 \
    > "$UE_LOG" 2>&1 &
echo "  UE PID: $! (log: $UE_LOG)"

echo ""
echo "Verificar E2 SETUP:"
echo "  grep -iE 'E2|RIC|setup' $GNB_LOG | tail -20"
