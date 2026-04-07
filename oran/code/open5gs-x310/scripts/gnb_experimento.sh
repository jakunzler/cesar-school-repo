#!/usr/bin/env bash
# Executa o gNB com um YAML do experimento FH/OFH (ajuste GNB_BIN ao seu ambiente).
set -euo pipefail

EXPERIMENTOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../ran/config/experimentos" && pwd)"

usage() {
  echo "Uso: sudo $0 <cenário>"
  echo "Cenários: A0 | A1 | A2 | A3 | A4 | A5 | A6 | list"
  echo ""
  echo "Defina GNB_BIN para o caminho absoluto do executável gnb (ex.: /opt/srsran/build/apps/gnb)"
  exit 1
}

[[ $# -ge 1 ]] || usage

case "$1" in
  list)
    ls -1 "$EXPERIMENTOS_DIR"/gnb_exp_*.yml 2>/dev/null || true
    exit 0
    ;;
  A0) CFG="gnb_exp_A0_baseline.yml" ;;
  A1) CFG="gnb_exp_A1_bw20_scs30.yml" ;;
  A2) CFG="gnb_exp_A2_bw40_scs30.yml" ;;
  A3) CFG="gnb_exp_A3_bw80_scs30.yml" ;;
  A4) CFG="gnb_exp_A4_bw100_scs30.yml" ;;
  A5) CFG="gnb_exp_A5_band77_bw100_scs30.yml" ;;
  A6) CFG="gnb_exp_A6_bw100_scs30_2t2r.yml" ;;
  *)  usage ;;
esac

YAML="$EXPERIMENTOS_DIR/$CFG"
if [[ ! -f "$YAML" ]]; then
  echo "Arquivo não encontrado: $YAML" >&2
  exit 1
fi

if [[ -z "${GNB_BIN:-}" ]]; then
  echo "Defina GNB_BIN com o caminho do executável gnb. Exemplo:" >&2
  echo "  export GNB_BIN=/caminho/para/gnb" >&2
  echo "  sudo -E $0 $1" >&2
  exit 1
fi

exec "$GNB_BIN" -c "$YAML"
