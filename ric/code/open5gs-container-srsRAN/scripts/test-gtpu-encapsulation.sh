#!/bin/bash

# Script para verificar encapsulamento GTP-U
# Autor: Jonas Augusto Kunzler
# Data: 2026-01-16

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ran-detect.sh
source "$SCRIPT_DIR/ran-detect.sh"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Teste de Encapsulamento GTP-U"
echo "=========================================="
echo ""

UE_CONTAINER=$(find_running_ue || true)
GNB_CONTAINER=$(find_running_gnb || true)
UPF_A_CONTAINER="upf-a"

if [ -z "$UE_CONTAINER" ]; then
    echo -e "${RED}❌ Nenhum container de UE em execução${NC}"
    exit 1
fi

# Verificar se tcpdump está disponível
if ! docker compose exec -T $UPF_A_CONTAINER which tcpdump >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  tcpdump não está disponível na UPF${NC}"
    echo "Instalando tcpdump..."
    docker compose exec -T $UPF_A_CONTAINER apt-get update >/dev/null 2>&1
    docker compose exec -T $UPF_A_CONTAINER apt-get install -y tcpdump >/dev/null 2>&1 || {
        echo -e "${RED}❌ Não foi possível instalar tcpdump${NC}"
        exit 1
    }
fi

echo "📡 Capturando tráfego GTP-U..."
echo ""

# Arquivo temporário para capturar saída do tcpdump no host
TMP_CAPTURE="$(mktemp)"

echo "Enviando tráfego do UE ($UE_CONTAINER)..."
ue_ping "$UE_CONTAINER" 8.8.8.8 5 2 >/dev/null 2>&1 &

echo "Capturando pacotes GTP-U na UPF (porta 2152)..."
# Executa tcpdump em background dentro do container, redirecionando saída para o host
docker compose exec -T $UPF_A_CONTAINER sh -lc "tcpdump -i any -n -c 10 'udp port 2152'" >"$TMP_CAPTURE" 2>&1 &
TCPDUMP_PID=$!

# Aguarda alguns segundos para gerar tráfego e capturar pacotes
sleep 6

# Encerra o tcpdump (se ainda estiver rodando)
if kill -0 "$TCPDUMP_PID" >/dev/null 2>&1; then
  kill "$TCPDUMP_PID" >/dev/null 2>&1 || true
  # pequena espera para flush
  sleep 1
fi

GTPU_CAPTURE="$(cat "$TMP_CAPTURE" 2>/dev/null || echo "")"
rm -f "$TMP_CAPTURE"

if echo "$GTPU_CAPTURE" | grep -q "udp .*2152"; then
    echo -e "${GREEN}✅ Tráfego GTP-U detectado!${NC}"
    echo ""
    echo "Pacotes capturados (até 10 linhas):"
    echo "$GTPU_CAPTURE" | head -10
    exit 0
else
    echo -e "${YELLOW}⚠️  Nenhum tráfego GTP-U capturado${NC}"
    echo "Isso pode indicar que o tráfego não está sendo encapsulado OU que a captura foi muito curta."
    exit 1
fi

