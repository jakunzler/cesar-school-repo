#!/bin/bash

# Script para capturar PCAPs nas redes N3 (gNB <-> UPF) e N6 (UPF <-> DN)
# Autor: Jonas Augusto Kunzler (ajustes automatizados)
#
# Uso:
#   ./scripts/capture-n3-n6-pcaps.sh
#
# O script:
#   - identifica automaticamente as interfaces N3 (10.30.0.21) e N6 (10.50.0.21) na UPF-A
#   - garante que tcpdump esteja instalado na UPF-A
#   - inicia capturas simultâneas em N3 (filtro GTP-U porta 2152) e N6 (tráfego IP geral)
#   - gera tráfego a partir do UE (ping 8.8.8.8)
#   - salva os PCAPs em:
#       logs/upf-a/n3-gtpu-<timestamp>.pcap
#       logs/upf-a/n6-dn-<timestamp>.pcap

set -euo pipefail

CAPTURE_SEC="${CAPTURE_SEC:-20}"

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

UPF_A_CONTAINER="upf-a"

echo "==============================================="
echo "Captura de PCAPs em N3 (GTP-U) e N6 (DN)"
echo "==============================================="
echo ""

# Verificar se Docker está rodando
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}ERRO: Docker não está rodando. Inicie o Docker primeiro.${NC}"
    exit 1
fi

UE_CONTAINER=$(find_running_ue || true)
if [ -z "$UE_CONTAINER" ]; then
    echo -e "${RED}ERRO: nenhum container de UE em execução.${NC}"
    echo "      Certifique-se de que o CORE e o RAN estão ativos:"
    echo "        ./scripts/up_core.sh"
    echo "        ./scripts/up_ran.sh"
    exit 1
fi

if ! docker compose ps --format "{{.Service}}" 2>/dev/null | grep -q "^${UPF_A_CONTAINER}$"; then
    echo -e "${RED}ERRO: serviço '${UPF_A_CONTAINER}' não está rodando via docker compose.${NC}"
    exit 1
fi

echo "🔍 Detectando interfaces N3 (10.30.x.x) e N6 (10.50.x.x) na UPF-A..."

N3_IF=$(docker compose exec -T "$UPF_A_CONTAINER" sh -lc "ip -o -4 addr show | awk '\$4 ~ /^10\\.30\\./ {print \$2; exit}'" | tr -d '\r')
N6_IF=$(docker compose exec -T "$UPF_A_CONTAINER" sh -lc "ip -o -4 addr show | awk '\$4 ~ /^10\\.50\\./ {print \$2; exit}'" | tr -d '\r')

if [ -z "$N3_IF" ]; then
  echo -e "${RED}ERRO: Não foi possível localizar interface com IP 10.30.x.x na UPF-A (rede N3).${NC}"
  exit 1
fi

if [ -z "$N6_IF" ]; then
  echo -e "${RED}ERRO: Não foi possível localizar interface com IP 10.50.x.x na UPF-A (rede N6).${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Interface N3 na UPF-A: ${N3_IF}${NC}"
echo -e "${GREEN}✅ Interface N6 na UPF-A: ${N6_IF}${NC}"
echo ""

# Verificar/instalar tcpdump na UPF-A
echo "Verificando se tcpdump está disponível na UPF-A..."
if ! docker compose exec -T "$UPF_A_CONTAINER" which tcpdump >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  tcpdump não encontrado. Instalando na UPF-A...${NC}"
    docker compose exec -T "$UPF_A_CONTAINER" sh -lc "apt-get update && apt-get install -y tcpdump" >/dev/null 2>&1 || {
        echo -e "${RED}❌ Falha ao instalar tcpdump na UPF-A${NC}"
        exit 1
    }
fi

TS="$(date +%Y%m%d-%H%M%S)"
N3_PCAP="/var/log/open5gs/n3-gtpu-${TS}.pcap"
N6_PCAP="/var/log/open5gs/n6-dn-${TS}.pcap"

echo "📁 Arquivos de saída esperados (visíveis no host):"
echo "  - logs/upf-a/$(basename "$N3_PCAP")"
echo "  - logs/upf-a/$(basename "$N6_PCAP")"
echo ""

echo "Iniciando capturas na UPF-A (${CAPTURE_SEC}s por interface, modo detached)..."

# -d: tcpdump roda dentro do container (evita wait infinito no docker compose exec do host).
# timeout: encerra após CAPTURE_SEC mesmo com pouco tráfego (-c 500 nunca era atingido com 30 pings).
docker compose exec -d "$UPF_A_CONTAINER" sh -lc \
  "timeout ${CAPTURE_SEC} tcpdump -i '${N3_IF}' -w '${N3_PCAP}' -n 'udp port 2152' 2>/dev/null" || true
docker compose exec -d "$UPF_A_CONTAINER" sh -lc \
  "timeout ${CAPTURE_SEC} tcpdump -i '${N6_IF}' -w '${N6_PCAP}' -n 2>/dev/null" || true

sleep 2

echo "Gerando tráfego a partir do UE ($UE_CONTAINER, ping 8.8.8.8)..."
ue_ping "$UE_CONTAINER" 8.8.8.8 "$CAPTURE_SEC" 1 >/dev/null 2>&1 &
PING_PID=$!

echo -n "Aguardando capturas (${CAPTURE_SEC}s)"
for _ in $(seq 1 "$CAPTURE_SEC"); do
  sleep 1
  echo -n "."
done
echo ""

wait "$PING_PID" 2>/dev/null || true
sleep 1

HOST_N3="logs/upf-a/$(basename "$N3_PCAP")"
HOST_N6="logs/upf-a/$(basename "$N6_PCAP")"
MISSING=0
# Header pcap global = 24 bytes; abaixo disso não há pacotes capturados.
for f in "$HOST_N3" "$HOST_N6"; do
  size=$(stat -c%s "$f" 2>/dev/null || echo 0)
  if [ ! -f "$f" ] || [ "$size" -le 24 ]; then
    echo -e "${YELLOW}⚠️  Sem pacotes capturados: $f (${size} bytes)${NC}"
    MISSING=1
  else
    echo -e "${GREEN}  ✓ $f (${size} bytes)${NC}"
  fi
done

if [ "$MISSING" -eq 1 ]; then
  echo -e "${YELLOW}Dica: aumente CAPTURE_SEC ou gere mais tráfego (ex.: CAPTURE_SEC=30 ./scripts/capture-n3-n6-pcaps.sh)${NC}"
fi

echo ""
echo -e "${GREEN}✅ Capturas finalizadas.${NC}"
echo "Você pode abrir os arquivos no host com, por exemplo:"
echo "  wireshark logs/upf-a/$(basename "$N3_PCAP")"
echo "  wireshark logs/upf-a/$(basename "$N6_PCAP")"
echo ""
echo "No PCAP de N3 você deve ver GTP-U (UDP/2152) entre gNB (10.30.0.11) e UPF-A (10.30.0.21)."
echo "No PCAP de N6 você deve ver tráfego IP entre a rede de UEs (10.60.0.0/16) e a DN (10.50.0.100 / internet)."
echo ""
echo "==============================================="
echo "Capturas N3/N6 concluídas com sucesso!"
echo "==============================================="
echo ""

