#!/bin/bash
#
# Script para verificar o status real do sistema
# Detecta problemas conhecidos e fornece informações detalhadas
#
# O UERANSIM roda em compose separado (ueransim/); este script roda a partir
# de core/ e usa docker logs/exec com nomes reais de containers.

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

UE_CONTAINER="${UE_CONTAINER:-ueransim}"
AMF_CONTAINER="${AMF_CONTAINER:-open5gs-amf-containerized}"
SMF_CONTAINER="${SMF_CONTAINER:-open5gs-smf-containerized}"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ueransim_logs() {
  docker logs "$UE_CONTAINER" 2>&1
}

amf_logs() {
  docker exec "$AMF_CONTAINER" sh -c 'tail -n 8000 /var/log/open5gs/amf.log 2>/dev/null' 2>/dev/null
}

smf_logs() {
  docker exec "$SMF_CONTAINER" sh -c 'tail -n 8000 /var/log/open5gs/smf.log 2>/dev/null' 2>/dev/null
}

echo "=========================================="
echo "Verificação de Status do Sistema"
echo "Open5GS Containerized"
echo "=========================================="
echo ""

# 1. Verificar containers
echo "📋 1. Status dos Containers"
echo "--------------------------------------------"
if docker ps --format '{{.Names}}' | grep -qx "$UE_CONTAINER"; then
    echo -e "${GREEN}✅ UERANSIM ($UE_CONTAINER): rodando${NC}"
else
    echo -e "${RED}❌ UERANSIM ($UE_CONTAINER): não está rodando${NC}"
    echo "   Suba com: (cd ../ueransim && ./scripts/up_ran.sh)"
fi

if docker compose ps --format '{{.Service}}' 2>/dev/null | grep -qx 'amf'; then
    echo -e "${GREEN}✅ AMF (compose core): rodando${NC}"
else
    echo -e "${RED}❌ AMF: não encontrado no compose do core${NC}"
fi

if docker compose ps --format '{{.Service}}' 2>/dev/null | grep -qx 'smf'; then
    echo -e "${GREEN}✅ SMF (compose core): rodando${NC}"
else
    echo -e "${RED}❌ SMF: não encontrado no compose do core${NC}"
fi
echo ""

# 2. Verificar NG Setup
echo "📡 2. Conexão N2 (gNB <-> AMF)"
echo "--------------------------------------------"
NG_SETUP_SUCCESS=$(ueransim_logs | grep -cE 'NG Setup procedure is successful|NGSetup|Setup successful' 2>/dev/null | head -1 || echo "0")
if [ "${NG_SETUP_SUCCESS:-0}" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✅ NG Setup bem-sucedido ($NG_SETUP_SUCCESS ocorrência(s) nos logs do UERANSIM)${NC}"
    LAST_NG_SETUP=$(ueransim_logs | grep -E 'NG Setup procedure is successful|NGSetup' | tail -1 | awk '{print $1, $2}' || echo "N/A")
    echo "   Última linha relevante: $LAST_NG_SETUP"
else
    echo -e "${YELLOW}⚠️  NG Setup não encontrado nos logs do ueransim (RAN parado ou texto diferente)${NC}"
fi

AMF_ACCEPTED=$(amf_logs | grep -c 'gNB-N2 accepted' 2>/dev/null | head -1 || echo "0")
if [ "${AMF_ACCEPTED:-0}" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✅ AMF aceitou gNB-N2 ($AMF_ACCEPTED vez(es) em amf.log)${NC}"
else
    echo -e "${YELLOW}⚠️  gNB-N2 accepted não encontrado em amf.log${NC}"
fi
echo ""

# 3. Verificar problema de AMF Context
echo "🔍 3. Problema de AMF Context"
echo "--------------------------------------------"
AMF_CONTEXT_ERROR=$(ueransim_logs | grep -c "AMF context not found" 2>/dev/null | head -1 || echo "0")
if [ "${AMF_CONTEXT_ERROR:-0}" -gt 0 ] 2>/dev/null; then
    echo -e "${RED}❌ Problema detectado: AMF context not found ($AMF_CONTEXT_ERROR ocorrência(s))${NC}"
    echo "   Possível incompatibilidade de versão UERANSIM / AMF."
    LAST_ERROR=$(ueransim_logs | grep "AMF context not found" | tail -1 | awk '{print $1, $2}' || echo "N/A")
    echo "   Última ocorrência: $LAST_ERROR"
else
    echo -e "${GREEN}✅ Nenhum erro de AMF context encontrado nos logs do UERANSIM${NC}"
fi
echo ""

# 4. Verificar status do UE
echo "📱 4. Status do UE"
echo "--------------------------------------------"
UE_IP=""
if docker ps --format '{{.Names}}' | grep -qx "$UE_CONTAINER"; then
  UE_IP=$(docker exec "$UE_CONTAINER" ip addr show 2>/dev/null | grep -oP 'inet \K10\.60\.\d+\.\d+' | head -1 || echo "")
  if [ -n "$UE_IP" ]; then
      echo -e "${GREEN}✅ UE possui IP: $UE_IP${NC}"
  else
      echo -e "${YELLOW}⚠️  UE sem IP 10.60.x.x${NC}"
  fi

  UE_CELL_FOUND=$(ueransim_logs | grep -cE "Selected cell|signal detected" 2>/dev/null | head -1 || echo "0")
  if [ "${UE_CELL_FOUND:-0}" -gt 0 ] 2>/dev/null; then
      echo -e "${GREEN}✅ UE encontrou células ($UE_CELL_FOUND indício(s))${NC}"
  else
      echo -e "${YELLOW}⚠️  Indícios de célula não encontrados nos logs${NC}"
  fi

  UE_REG_STATE=$(ueransim_logs | grep "UE switches to state" | tail -1 | grep -oP "\[MM-[^\]]+\]" || echo "")
  if [ -n "$UE_REG_STATE" ]; then
      if echo "$UE_REG_STATE" | grep -q "REGISTERED"; then
          echo -e "${GREEN}✅ UE registrado: $UE_REG_STATE${NC}"
      elif echo "$UE_REG_STATE" | grep -q "ATTEMPTING-REGISTRATION"; then
          echo -e "${YELLOW}⚠️  UE tentando registro: $UE_REG_STATE${NC}"
      else
          echo -e "${RED}❌ Estado MM inesperado: $UE_REG_STATE${NC}"
      fi
  fi
else
  echo -e "${YELLOW}⚠️  Container $UE_CONTAINER não está ativo — pule para ../ueransim e suba o RAN.${NC}"
fi
echo ""

# 5. Verificar sessão PDU
echo "🔗 5. Sessão PDU"
echo "--------------------------------------------"
PFCP_ASSOCIATED=$(smf_logs | grep -c "PFCP associated" 2>/dev/null | head -1 || echo "0")
if [ "${PFCP_ASSOCIATED:-0}" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✅ Associação PFCP estabelecida (indicadores em smf.log: $PFCP_ASSOCIATED)${NC}"
else
    echo -e "${YELLOW}⚠️  Associação PFCP não encontrada em smf.log${NC}"
fi

if docker ps --format '{{.Names}}' | grep -qx "$UE_CONTAINER"; then
  if [ -n "$UE_IP" ] && docker exec "$UE_CONTAINER" ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
      echo -e "${GREEN}✅ Conectividade ativa (ping 8.8.8.8 OK)${NC}"
  elif [ -n "$UE_IP" ]; then
      echo -e "${YELLOW}⚠️  Ping 8.8.8.8 falhou (verifique sessão PDU / rotas)${NC}"
  fi
fi
echo ""

# 6. Resumo
echo "=========================================="
echo "Resumo"
echo "=========================================="
echo ""
if [ "${AMF_CONTEXT_ERROR:-0}" -gt 0 ] 2>/dev/null; then
    echo -e "${RED}⚠️  Verifique compatibilidade UERANSIM ↔ Open5GS AMF.${NC}"
elif docker ps --format '{{.Names}}' | grep -qx "$UE_CONTAINER" && [ -n "$UE_IP" ]; then
    echo -e "${GREEN}✅ Indicadores principais OK (UE com IP; revise logs acima).${NC}"
else
    echo -e "${YELLOW}⚠️  Suba o RAN ou confira assinante / gnb.yaml / ue.yaml.${NC}"
fi

echo "=========================================="
echo "Fim da Verificação"
echo "=========================================="
