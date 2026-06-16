#!/bin/bash
# Compila nearRT-RIC e xApps FlexRIC (branch dev) alinhados ao gNB E2.
# Uso: ./scripts/build_flexric_tools.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FLEXRIC="$PROJECT_DIR/openairinterface5g/openair2/E2AP/flexric"
BUILD="$FLEXRIC/build"

echo "Compilando FlexRIC tools (dev, E2AP_V2, KPM_V2_03)..."

if [ ! -f "$FLEXRIC/CMakeLists.txt" ]; then
    echo "ERRO: Submodule FlexRIC ausente. Execute ./scripts/build_e2.sh"
    exit 1
fi

mkdir -p "$BUILD"
cd "$BUILD"
cmake .. -GNinja -DE2AP_VERSION=E2AP_V2 -DKPM_VERSION=KPM_V2_03
ninja nearRT-RIC \
    libkpm_sm.so librc_sm.so libmac_sm.so librlc_sm.so libpdcp_sm.so libgtp_sm.so libtc_sm.so libslice_sm.so \
    xapp_rc_moni xapp_kpm_moni xapp_kpm_rc xapp_gtp_mac_rlc_pdcp_moni

"$SCRIPT_DIR/sync_flexric_lib.sh"

echo ""
echo "Binários em: $BUILD/examples/"
echo "SMs em: ${FLEXRIC_LIB_DIR:-$PROJECT_DIR/flexric-lib}/"
echo "  ric/nearRT-RIC"
echo "  xApp/c/monitor/xapp_rc_moni"
echo "  xApp/c/monitor/xapp_kpm_moni"
echo "  xApp/c/monitor/xapp_gtp_mac_rlc_pdcp_moni"
echo "  xApp/c/kpm_rc/xapp_kpm_rc"
