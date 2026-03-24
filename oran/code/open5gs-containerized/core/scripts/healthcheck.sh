#!/bin/bash
# Script para verificar a saúde dos serviços Open5GS
# Detecta problemas conhecidos e fornece informações relevantes
# Uso: ./scripts/healthcheck.sh
#
# Autor: Jonas Augusto Kunzler
# Data: 2026-01-15

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

# IP do gNB na rede N2 (deve coincidir com ueransim/configs/gnb.yaml → linkIp/ngapIp)
GNB_N2_IP="${GNB_N2_IP:-10.20.0.101}"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "Healthcheck - Laboratório Open5GS"
echo "=========================================="
echo ""

# Verificar status dos containers
echo "Status dos containers:"
docker compose ps
echo ""

# Verificar processos dos serviços
echo "Verificando processos dos serviços..."
declare -A SERVICE_CONTAINERS=(
    ["nrf"]="open5gs-nrf-containerized"
    ["scp"]="open5gs-scp-containerized"
    ["amf"]="open5gs-amf-containerized"
    ["smf"]="open5gs-smf-containerized"
    ["ausf"]="open5gs-ausf-containerized"
    ["udm"]="open5gs-udm-containerized"
    ["udr"]="open5gs-udr-containerized"
    ["pcf"]="open5gs-pcf-containerized"
    ["nssf"]="open5gs-nssf-containerized"
    ["upf"]="open5gs-upf-containerized"
)

for service in "${!SERVICE_CONTAINERS[@]}"; do
    container="${SERVICE_CONTAINERS[$service]}"
    if docker exec "$container" pgrep -f "open5gs-" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ ${service} está rodando${NC}"
    else
        echo -e "${RED}✗ ${service} não está rodando${NC}"
    fi
done
echo ""

# Verificar conectividade NRF
echo "Verificando NRF..."
# NRF usa HTTP/2 puro (nghttp2) que não é facilmente testável com curl simples
# Verificamos se o processo está rodando e se a porta está escutando
if docker exec open5gs-nrf-containerized pgrep -f "open5gs-nrfd" > /dev/null 2>&1; then
    if docker exec open5gs-nrf-containerized netstat -tlnp 2>/dev/null | grep -q ":7777" || \
       docker exec open5gs-nrf-containerized ss -tlnp 2>/dev/null | grep -q ":7777"; then
        echo -e "${GREEN}✓ NRF está rodando e escutando na porta 7777${NC}"
    else
        echo -e "${YELLOW}⚠ NRF está rodando mas porta 7777 não está escutando${NC}"
    fi
else
    echo -e "${RED}✗ NRF não está rodando${NC}"
fi
echo ""

# Verificar se NFs estão registradas no NRF
echo "Verificando registro de NFs no NRF..."
# Nota: O endpoint HTTP/2 do NRF requer cliente HTTP/2 nativo (nghttp2)
# Como alternativa, verificamos se as NFs estão rodando e se o NRF está healthy
# O registro real é verificado pelos logs e pelo fato de as NFs estarem funcionando
if docker compose ps nrf | grep -q "healthy"; then
    echo "✓ NRF está healthy (NFs devem estar registradas)"
    echo "  (Para verificar registro detalhado, consulte os logs: docker compose logs nrf | grep 'NF registered')"
else
    echo "⚠ NRF não está healthy ainda"
fi
echo ""

# Verificar conectividade entre serviços
echo "Verificando conectividade de rede..."
echo "Testando N2 (AMF <-> gNB em ${GNB_N2_IP}):"
if docker exec open5gs-amf-containerized ping -c 1 -W 2 "$GNB_N2_IP" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ AMF pode alcançar gNB${NC}"
else
    echo -e "${RED}✗ AMF não alcança gNB (ajuste GNB_N2_IP ou confira gnb.yaml)${NC}"
fi

echo "Testando N3 (gNB <-> UPF):"
if docker exec ueransim ping -c 1 10.30.0.21 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ (UERANSIM) gNB pode alcançar UPF${NC}"
else
    echo -e "${RED}✗ gNB não pode alcançar UPF${NC}"
fi

echo "Testando N4 (SMF <-> UPF):"
if docker exec open5gs-smf-containerized ping -c 1 10.40.0.21 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ SMF pode alcançar UPF${NC}"
else
    echo -e "${RED}✗ SMF não pode alcançar UPF${NC}"
fi

echo "Testando N4 (SMF <-> UPF-B):"
echo "Testando N6 (UPF <-> DN):"
if docker exec open5gs-upf-containerized ping -c 1 10.50.0.100 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ UPF pode alcançar DN${NC}"
else
    echo -e "${RED}✗ UPF não pode alcançar DN${NC}"
fi
echo ""

# Verificar NG Setup (UERANSIM está em compose separado — usar docker logs, não compose do core)
echo "Verificando NG Setup (gNB <-> AMF)..."
if docker ps --format '{{.Names}}' | grep -qx 'ueransim'; then
NG_SETUP_SUCCESS=$(docker logs ueransim 2>&1 | grep -cE 'NG Setup procedure is successful|NGSetup|Setup successful' 2>/dev/null | head -1 || echo "0")
else
NG_SETUP_SUCCESS=0
fi
if [ "$NG_SETUP_SUCCESS" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✓ NG Setup bem-sucedido ($NG_SETUP_SUCCESS vez(es))${NC}"
else
    echo -e "${YELLOW}⚠ NG Setup não encontrado nos logs do ueransim (RAN parado ou mensagem diferente)${NC}"
fi

# Verificar problema de AMF Context
if docker ps --format '{{.Names}}' | grep -qx 'ueransim'; then
AMF_CONTEXT_ERROR=$(docker logs ueransim 2>&1 | grep -c "AMF context not found" 2>/dev/null | head -1 || echo "0")
else
AMF_CONTEXT_ERROR=0
fi
if [ "$AMF_CONTEXT_ERROR" -gt 0 ] 2>/dev/null; then
    echo -e "${RED}⚠ Problema detectado: AMF context not found ($AMF_CONTEXT_ERROR ocorrência(s))${NC}"
    echo "   Execute: ./scripts/test-system-status.sh para mais detalhes"
else
    echo -e "${GREEN}✓ Nenhum erro de AMF context encontrado${NC}"
fi
echo ""

# Verificar associação PFCP (stdout do container pode estar vazio; preferir arquivo de log)
echo "Verificando associação PFCP (SMF <-> UPF)..."
PFCP_ASSOCIATED=$(docker compose logs smf 2>&1 | grep -c "PFCP associated" 2>/dev/null | head -1 || echo "0")
if [ "${PFCP_ASSOCIATED:-0}" -eq 0 ] 2>/dev/null; then
  PFCP_ASSOCIATED=$(docker exec open5gs-smf-containerized sh -c 'tail -n 6000 /var/log/open5gs/smf.log 2>/dev/null' | grep -c "PFCP associated" 2>/dev/null | head -1 || echo "0")
fi
if [ "$PFCP_ASSOCIATED" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✓ Associação PFCP estabelecida (SMF <-> UPF)${NC}"
else
    echo -e "${YELLOW}⚠ Associação PFCP não encontrada${NC}"
fi
echo ""

# Verificar se UE está conectado (container real: ueransim)
echo "Verificando status do UE (UERANSIM)..."
UERANSIM_C="ueransim"
if ! docker ps --format '{{.Names}}' | grep -qx "$UERANSIM_C"; then
    echo -e "${YELLOW}⚠ Container $UERANSIM_C não está rodando (subir: ueransim/scripts/up_ran.sh)${NC}"
else
if docker exec "$UERANSIM_C" pgrep -f "nr-ue" > /dev/null 2>&1 || docker exec "$UERANSIM_C" pgrep -f "nr-gnb" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Processos UERANSIM (nr-ue / nr-gnb) ativos${NC}"
    
    UE_IP=$(docker exec "$UERANSIM_C" ip addr show 2>/dev/null | grep -oP 'inet \K10\.60\.\d+\.\d+' | head -1 || echo "")
    if [ -n "$UE_IP" ]; then
        echo -e "${GREEN}  ✓ UE possui IP: $UE_IP${NC}"
        if docker exec "$UERANSIM_C" ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
            echo -e "${GREEN}  ✓ Conectividade ativa${NC}"
        else
            echo -e "${YELLOW}  ⚠ Sem ping 8.8.8.8 (IP pode ser antigo)${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠ UE sem IP 10.60.x.x visível${NC}"
    fi
    
    UE_CELL_FOUND=$(docker logs "$UERANSIM_C" 2>&1 | grep -cE "Selected cell|signal detected" 2>/dev/null | head -1 || echo "0")
    if [ "$UE_CELL_FOUND" -gt 0 ] 2>/dev/null; then
        echo -e "${GREEN}  ✓ UE encontrou células${NC}"
    else
        echo -e "${YELLOW}  ⚠ Indícios de célula não encontrados nos logs recentes${NC}"
    fi
else
    echo -e "${RED}✗ Processos nr-ue/nr-gnb não encontrados em $UERANSIM_C${NC}"
fi
fi

echo ""
echo "=========================================="
echo "Healthcheck concluído"
echo "=========================================="
echo ""
echo "💡 Dicas:"
echo "  - Para verificação detalhada: ../core/scripts/test-system-status.sh"
echo "  - Para teste de conectividade: ../ueransim/scripts/test_ue_connection.sh"
echo ""
