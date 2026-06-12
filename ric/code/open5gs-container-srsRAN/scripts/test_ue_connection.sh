#!/bin/bash

# Script para testar a conexão end-to-end do UE
# Autor: Jonas Augusto Kunzler
# Data: 2025-12-19

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=ran-detect.sh
source "$SCRIPT_DIR/ran-detect.sh"

cd "$PROJECT_DIR"

TEST_HOSTS=("8.8.8.8" "8.8.4.4" "1.1.1.1")
TEST_URLS=("http://ifconfig.me" "http://icanhazip.com")

echo "=========================================="
echo "Teste de Conexão End-to-End - UE"
echo "=========================================="
echo ""

UE_CONTAINER=$(find_running_ue || true)
GNB_CONTAINER=$(find_running_gnb || true)

if [ -z "$UE_CONTAINER" ]; then
    echo "❌ Erro: Nenhum container de UE em execução!"
    echo "   Esperado: ueransim-ue-containerized, ueransim ou srsran-ue-containerized"
    echo "   Execute: ./scripts/up.sh ou ./scripts/up_ran.sh"
    exit 1
fi

echo "✅ Container UE ativo: $UE_CONTAINER"
echo ""

echo "📡 Verificando IP do UE..."
UE_ACTUAL_IP=$(docker exec "$UE_CONTAINER" ip -4 addr show 2>/dev/null | grep -oP 'inet \K10\.60\.\d+\.\d+' | head -1 || echo "")

if [ -z "$UE_ACTUAL_IP" ]; then
    echo "❌ Erro: UE não possui IP atribuído!"
    echo "   Verifique se a sessão PDU foi estabelecida corretamente."
    exit 1
fi

echo "✅ UE possui IP: $UE_ACTUAL_IP"
TUN_IF=$(get_ue_tunnel "$UE_CONTAINER")
echo ""

echo "🔍 Teste 1: Ping para servidores DNS públicos"
echo "--------------------------------------------"
for host in "${TEST_HOSTS[@]}"; do
    echo -n "  Testando $host... "
    if ue_ping_ok "$UE_CONTAINER" "$host" 2 2; then
        RTT=$(ue_ping "$UE_CONTAINER" "$host" 2 2 2>&1 | grep "avg" | awk -F'/' '{print $5}')
        echo "✅ OK (RTT médio: ${RTT}ms)"
    else
        echo "❌ FALHOU"
    fi
done
echo ""

echo "🔍 Teste 2: Resolução DNS"
echo "--------------------------------------------"
TEST_DOMAIN="google.com"
echo -n "  Resolvendo $TEST_DOMAIN... "
if docker exec "$UE_CONTAINER" nslookup "$TEST_DOMAIN" > /dev/null 2>&1; then
    IP=$(docker exec "$UE_CONTAINER" nslookup "$TEST_DOMAIN" 2>&1 | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -1)
    echo "✅ OK (IP: $IP)"
else
    echo "❌ FALHOU"
fi
echo ""

echo "🔍 Teste 3: Acesso HTTP"
echo "--------------------------------------------"
for url in "${TEST_URLS[@]}"; do
    echo -n "  Testando $url... "
    if docker exec "$UE_CONTAINER" wget -q --timeout=5 -O- "$url" > /dev/null 2>&1; then
        IP=$(docker exec "$UE_CONTAINER" wget -q --timeout=5 -O- "$url" 2>&1 | head -1)
        echo "✅ OK (IP público: $IP)"
    else
        echo "❌ FALHOU"
    fi
done
echo ""

echo "🔍 Teste 4: Verificar rota padrão (container UE)"
echo "--------------------------------------------"
DEFAULT_GW=$(docker exec "$UE_CONTAINER" ip route | grep default | awk '{print $3}' || echo "não encontrado")
echo "  Gateway padrão: $DEFAULT_GW"
echo ""

echo "🔍 Teste 5: Conectividade com UPFs (N4)"
echo "--------------------------------------------"
UPF_A_IP="10.40.0.21"
UPF_B_IP="10.40.0.22"
for upf_ip in "$UPF_A_IP" "$UPF_B_IP"; do
    echo -n "  Testando conectividade com UPF ($upf_ip)... "
    if docker exec "$UE_CONTAINER" ping -c 1 -W 1 "$upf_ip" > /dev/null 2>&1; then
        echo "✅ OK"
    else
        echo "⚠️  Não acessível diretamente (normal - UPF não responde ping)"
    fi
done
echo ""

echo "🔍 Teste 6: Verificar sessão PDU e registro de UE"
echo "--------------------------------------------"
echo "  Verificando conexão N2 (AMF <-> gNB)..."
if docker compose logs amf 2>&1 | grep -q "gNB-N2 accepted\|ngap.*accepted"; then
    echo "  ✅ Conexão N2 estabelecida (gNB conectado ao AMF)"
else
    echo "  ⚠️  Conexão N2 não encontrada nos logs"
fi

echo "  Verificando associação PFCP (SMF <-> UPF)..."
if docker compose logs smf 2>&1 | grep -q "PFCP associated"; then
    UPF_COUNT=$(docker compose logs smf 2>&1 | grep -c "PFCP associated" || echo "0")
    echo "  ✅ Associação PFCP estabelecida ($UPF_COUNT UPF(s) associado(s))"
else
    echo "  ⚠️  Associação PFCP não encontrada nos logs"
fi

AMF_CONTEXT_ERROR=0
for gnb in "${GNB_CONTAINERS[@]}"; do
    container_running "$gnb" || continue
    COUNT=$(docker logs "$gnb" 2>&1 | grep -c "AMF context not found" 2>/dev/null | head -1 || echo "0")
    AMF_CONTEXT_ERROR=$((AMF_CONTEXT_ERROR + COUNT))
done

if [ "$AMF_CONTEXT_ERROR" -gt 0 ] 2>/dev/null; then
    echo "  ❌ Problema detectado: AMF context not found ($AMF_CONTEXT_ERROR ocorrência(s))"
    echo "     Isso impede o registro de novos UEs"
    echo "     Execute: ./scripts/test-system-status.sh para mais detalhes"
else
    UE_REG_STATE=$(docker logs "$UE_CONTAINER" 2>&1 | grep "UE switches to state" | tail -1 | grep -oP "\[MM-[^\]]+\]" || echo "")
    if echo "$UE_REG_STATE" | grep -q "REGISTERED"; then
        echo "  ✅ UE registrado no AMF: $UE_REG_STATE"
    elif [ -n "$UE_ACTUAL_IP" ] && ue_ping_ok "$UE_CONTAINER" 8.8.8.8 1 1; then
        echo "  ⚠️  Registro não encontrado nos logs, mas UE tem IP e conectividade"
        echo "     (Pode ser estado antigo de sessão anterior)"
    else
        echo "  ⚠️  UE não está registrado"
    fi
fi

echo ""
echo "  💡 Dica: Execute './scripts/test-system-status.sh' para verificação detalhada do sistema"
echo ""

echo "=========================================="
echo "Resumo dos Testes"
echo "=========================================="
echo ""
echo "Container UE: $UE_CONTAINER"
[ -n "$GNB_CONTAINER" ] && echo "Container gNB: $GNB_CONTAINER"
echo "IP do UE: $UE_ACTUAL_IP"
[ -n "$TUN_IF" ] && echo "Interface TUN: $TUN_IF"
echo "Gateway: $DEFAULT_GW"
echo ""
echo "✅ Testes de conectividade básica concluídos!"
echo ""
