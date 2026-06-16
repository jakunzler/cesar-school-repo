#!/bin/bash
# Compila OAI gNB + nrUE com agente E2/FlexRIC integrado.
#
# Uso:
#   ./scripts/build_gnb_e2.sh
#
# Variáveis opcionais:
#   E2AP_VERSION=E2AP_V2
#   KPM_VERSION=KPM_V2_03
#   OAI_LOG_DIR=/caminho/para/logs
#   CLEAN_BUILD=1
#   INSTALL_DEPS=0
#
# Exemplos:
#   ./scripts/build_gnb_e2.sh
#   CLEAN_BUILD=0 ./scripts/build_gnb_e2.sh
#   INSTALL_DEPS=1 ./scripts/build_gnb_e2.sh
#   E2AP_VERSION=E2AP_V2 KPM_VERSION=KPM_V2_03 ./scripts/build_gnb_e2.sh
#
# Observações:
# - Requer FlexRIC submodule em openair2/E2AP/flexric.
# - Requer Service Models instalados em /usr/local/lib/flexric/.
# - O build usa RF simulator (-w SIMU).
# - O build gera binários em openairinterface5g/cmake_targets/ran_build/build/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

OAI_DIR="$PROJECT_DIR/openairinterface5g"
FLEXRIC_DIR="$OAI_DIR/openair2/E2AP/flexric"
BUILD_DIR="$OAI_DIR/cmake_targets"
RAN_BUILD_DIR="$BUILD_DIR/ran_build/build"

LOG_DIR="${OAI_LOG_DIR:-$PROJECT_DIR/logs}"
LOG_FILE="$LOG_DIR/build_gnb_e2.log"

E2AP_VERSION="${E2AP_VERSION:-E2AP_V2}"
KPM_VERSION="${KPM_VERSION:-KPM_V2_03}"

CLEAN_BUILD="${CLEAN_BUILD:-1}"
INSTALL_DEPS="${INSTALL_DEPS:-0}"

echo "=========================================="
echo "Build OAI gNB + nrUE com E2 Agent/FlexRIC"
echo "=========================================="
echo "Projeto:       $PROJECT_DIR"
echo "OAI_DIR:       $OAI_DIR"
echo "BUILD_DIR:     $BUILD_DIR"
echo "RAN_BUILD_DIR: $RAN_BUILD_DIR"
echo "FlexRIC dir:   $FLEXRIC_DIR"
echo "E2AP_VERSION:  $E2AP_VERSION"
echo "KPM_VERSION:   $KPM_VERSION"
echo "CLEAN_BUILD:   $CLEAN_BUILD"
echo "INSTALL_DEPS:  $INSTALL_DEPS"
echo "Log:           $LOG_FILE"
echo "=========================================="

mkdir -p "$LOG_DIR"

# Evita crescimento indefinido de log anterior.
if [ -f "$LOG_FILE" ]; then
    mv "$LOG_FILE" "${LOG_FILE}.$(date +%Y%m%d_%H%M%S).bak"
fi

# Limpa logs antigos de build, mantendo no máximo os 3 mais recentes.
find "$LOG_DIR" -maxdepth 1 -name "build_gnb_e2.log.*.bak" -type f \
    | sort \
    | head -n -3 \
    | xargs -r rm -f

# Valida estrutura do projeto.
if [ ! -d "$OAI_DIR" ]; then
    echo "ERRO: diretório OAI não encontrado:"
    echo "  $OAI_DIR"
    exit 1
fi

if [ ! -x "$BUILD_DIR/build_oai" ]; then
    echo "ERRO: script build_oai não encontrado ou não executável:"
    echo "  $BUILD_DIR/build_oai"
    exit 1
fi

# FlexRIC submodule necessário para E2.
if [ ! -f "$FLEXRIC_DIR/CMakeLists.txt" ]; then
    echo ""
    echo "FlexRIC não encontrado em:"
    echo "  $FLEXRIC_DIR"
    echo ""
    echo "Clonando FlexRIC branch dev..."
    mkdir -p "$(dirname "$FLEXRIC_DIR")"
    git clone --branch dev --depth 1 \
        https://gitlab.eurecom.fr/mosaic5g/flexric.git "$FLEXRIC_DIR"
fi

# Verifica Service Models instalados no sistema.
echo ""
echo "Verificando Service Models do FlexRIC..."
if [ ! -d /usr/local/lib/flexric ] || [ -z "$(ls -A /usr/local/lib/flexric/*.so 2>/dev/null || true)" ]; then
    echo "AVISO: Service Models não encontrados em /usr/local/lib/flexric/"
    echo "       O build pode até concluir, mas o E2 agent pode falhar em runtime."
    echo "       Instale o FlexRIC e os Service Models antes de rodar o gNB com E2."
else
    echo "Service Models encontrados:"
    ls -1 /usr/local/lib/flexric/*.so
fi

# Verifica suporte a --build-e2 no build_oai.
echo ""
echo "Verificando suporte do build_oai a --build-e2..."
if "$BUILD_DIR/build_oai" --help 2>/dev/null | grep -q -- "--build-e2"; then
    HAS_BUILD_E2=1
    echo "OK: build_oai suporta --build-e2."
else
    HAS_BUILD_E2=0
    echo "ERRO: build_oai desta árvore não parece suportar --build-e2."
    echo "     Verifique se a versão do OAI é compatível com E2 Agent/FlexRIC."
    exit 1
fi

cd "$BUILD_DIR"

# Instala dependências se solicitado.
if [ "$INSTALL_DEPS" = "1" ]; then
    echo ""
    echo "Instalando dependências OAI..."
    ./build_oai --ninja -I --build-e2 2>&1 | tee -a "$LOG_FILE"
else
    echo ""
    echo "Pulando instalação de dependências OAI."
    echo "Para executar dependências antes do build:"
    echo "  INSTALL_DEPS=1 ./scripts/build_gnb_e2.sh"
fi

# Define flag de clean.
CLEAN_ARG=""
if [ "$CLEAN_BUILD" = "1" ]; then
    CLEAN_ARG="-c"
fi

echo ""
echo "Iniciando compilação gNB + nrUE com E2..."
echo ""

./build_oai \
    --ninja \
    --gNB \
    --nrUE \
    --build-e2 \
    -w SIMU \
    $CLEAN_ARG \
    --cmake-opt "-DE2AP_VERSION=${E2AP_VERSION}" \
    --cmake-opt "-DKPM_VERSION=${KPM_VERSION}" \
    2>&1 | tee -a "$LOG_FILE"

echo ""
echo "=========================================="
echo "Verificação pós-build"
echo "=========================================="

if [ ! -d "$RAN_BUILD_DIR" ]; then
    echo "ERRO: diretório de build não encontrado:"
    echo "  $RAN_BUILD_DIR"
    exit 1
fi

NR_SOFTMODEM="$RAN_BUILD_DIR/nr-softmodem"
NR_UE_SOFTMODEM="$RAN_BUILD_DIR/nr-uesoftmodem"

if [ ! -x "$NR_SOFTMODEM" ]; then
    echo "ERRO: nr-softmodem não encontrado ou não executável:"
    echo "  $NR_SOFTMODEM"
    echo ""
    echo "Arquivos executáveis encontrados:"
    find "$RAN_BUILD_DIR" -maxdepth 2 -type f -executable | sort
    exit 1
fi

if [ ! -x "$NR_UE_SOFTMODEM" ]; then
    echo "ERRO: nr-uesoftmodem não encontrado ou não executável:"
    echo "  $NR_UE_SOFTMODEM"
    echo ""
    echo "Arquivos executáveis encontrados:"
    find "$RAN_BUILD_DIR" -maxdepth 2 -type f -executable | sort
    exit 1
fi

echo "OK: binários encontrados:"
echo "  $NR_SOFTMODEM"
echo "  $NR_UE_SOFTMODEM"

echo ""
echo "Verificando indícios de E2 no nr-softmodem..."
if strings "$NR_SOFTMODEM" | grep -qiE "e2|flexric|E2AP|KPM"; then
    echo "OK: binário contém strings relacionadas a E2/FlexRIC/KPM."
else
    echo "AVISO: não foram encontradas strings evidentes de E2/FlexRIC/KPM no binário."
    echo "       Isso não garante falha, mas recomenda validação em runtime."
fi

echo ""
echo "Tamanho dos binários:"
du -h "$NR_SOFTMODEM" "$NR_UE_SOFTMODEM"

echo ""
echo "Uso de disco do build:"
du -sh "$RAN_BUILD_DIR"

echo ""
echo "=========================================="
echo "Build concluído com sucesso."
echo "=========================================="
echo "Binários:"
echo "  gNB:  $NR_SOFTMODEM"
echo "  nrUE: $NR_UE_SOFTMODEM"
echo ""
echo "Log:"
echo "  $LOG_FILE"
echo ""
echo "Próximo passo sugerido:"
echo "  cd $PROJECT_DIR"
echo "  ./scripts/up_gnb_oai.sh"
echo "=========================================="