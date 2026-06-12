#!/bin/bash
# Script para derrubar apenas os RANs (UERANSIM + srsRAN gNB)
# Uso: ./scripts/down_ran.sh
# Requer: CORE já rodando (./scripts/up_core.sh ou ./scripts/up.sh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "=========================================="
echo "Derrubando RAN (UERANSIM + srsRAN gNB)"
echo "=========================================="
echo ""

# Verificar se Docker está rodando
if ! docker info > /dev/null 2>&1; then
    echo "ERRO: Docker não está rodando. Por favor, inicie o Docker primeiro."
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    echo "ERRO: docker compose não está disponível. Instale Docker Compose plugin."
    exit 1
fi

# ----------------------------------------------------------------------------
echo ""
echo "Derrubando UERANSIM split (gNB + UE)..."
docker compose down ueransim-gnb ueransim-ue

echo ""
echo "=========================================="
echo "RAN derrubado!"
echo "=========================================="
echo ""

echo "💡 Para reiniciar: ./scripts/up_ran.sh"
echo "   (Certifique-se de que o CORE está rodando: ./scripts/up_core.sh)"
echo ""
