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
#   FLEXRIC_LIB_DIR=/caminho/para/flexric-lib
#   CLEAN_BUILD=1
#   INSTALL_DEPS=0
#   BUILD_FLEXRIC_TOOLS=1   compila nearRT-RIC, SMs e xApps (test_e2_*.sh)
#
# Exemplos:
#   ./scripts/build_gnb_e2.sh
#   CLEAN_BUILD=0 ./scripts/build_gnb_e2.sh
#   INSTALL_DEPS=1 ./scripts/build_gnb_e2.sh
#   E2AP_VERSION=E2AP_V2 KPM_VERSION=KPM_V2_03 ./scripts/build_gnb_e2.sh
#
# Observações:
# - Requer FlexRIC submodule em openair2/E2AP/flexric.
# - Os testes E2 usam SMs em flexric-lib/ (não /usr/local/lib/flexric/).
# - Por padrão também compila nearRT-RIC e xApps via build_flexric_tools.sh.
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
FLEXRIC_LIB="${FLEXRIC_LIB_DIR:-$PROJECT_DIR/flexric-lib}"
[[ "$FLEXRIC_LIB" == */ ]] || FLEXRIC_LIB="${FLEXRIC_LIB}/"
FLEXRIC_BUILD="$FLEXRIC_DIR/build"
XAPP_MONITOR="$FLEXRIC_BUILD/examples/xApp/c/monitor"
RIC_BIN="$FLEXRIC_BUILD/examples/ric/nearRT-RIC"

E2AP_VERSION="${E2AP_VERSION:-E2AP_V2}"
KPM_VERSION="${KPM_VERSION:-KPM_V2_03}"

CLEAN_BUILD="${CLEAN_BUILD:-1}"
INSTALL_DEPS="${INSTALL_DEPS:-0}"
BUILD_FLEXRIC_TOOLS="${BUILD_FLEXRIC_TOOLS:-1}"

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
echo "BUILD_FLEXRIC: $BUILD_FLEXRIC_TOOLS"
echo "FlexRIC libs:  $FLEXRIC_LIB"
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

# Service Models usados em runtime pelos scripts de teste (flexric-lib/).
echo ""
echo "Verificando Service Models do FlexRIC (flexric-lib/)..."
if [ -f "$FLEXRIC_LIB/libkpm_sm.so" ] && [ -f "$FLEXRIC_LIB/librc_sm.so" ]; then
    echo "OK: SMs já presentes em $FLEXRIC_LIB"
    ls -1 "$FLEXRIC_LIB"/*.so 2>/dev/null || true
elif [ -d /usr/local/lib/flexric ] && [ -n "$(ls -A /usr/local/lib/flexric/*.so 2>/dev/null || true)" ]; then
    echo "AVISO: SMs em /usr/local/lib/flexric/ encontrados, mas os testes usam $FLEXRIC_LIB"
    echo "       Serão compilados/sincronizados após o build OAI (BUILD_FLEXRIC_TOOLS=1)."
else
    echo "AVISO: SMs ainda ausentes em $FLEXRIC_LIB"
    echo "       Serão compilados após o build OAI (BUILD_FLEXRIC_TOOLS=1)."
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

# nearRT-RIC, SMs (flexric-lib/) e xApps exigidos por test_e2_*.sh
if [ "$BUILD_FLEXRIC_TOOLS" = "1" ]; then
    echo ""
    echo "=========================================="
    echo "Build FlexRIC (nearRT-RIC, SMs, xApps)"
    echo "=========================================="
    E2AP_VERSION="$E2AP_VERSION" KPM_VERSION="$KPM_VERSION" \
        "$SCRIPT_DIR/build_flexric_tools.sh" 2>&1 | tee -a "$LOG_FILE"
else
    echo ""
    echo "Pulando build FlexRIC (BUILD_FLEXRIC_TOOLS=0)."
    echo "Os testes E2 exigem flexric-lib/ e xApps: ./scripts/build_flexric_tools.sh"
fi

verify_test_resources() {
    local missing=0

    check_file() {
        local label="$1"
        local path="$2"
        if [ -f "$path" ] || [ -x "$path" ]; then
            echo "  OK  $label"
        else
            echo "  FALTA  $label ($path)"
            missing=1
        fi
    }

    echo ""
    echo "Verificando artefatos para test_e2_sm.sh / test_e2_kpm.sh / test_e2_rc_attach.sh..."

    check_file "nr-softmodem (gNB + E2 agent)" "$NR_SOFTMODEM"
    check_file "nr-uesoftmodem (UE RFSIM)" "$NR_UE_SOFTMODEM"
    check_file "nearRT-RIC" "$RIC_BIN"
    check_file "libkpm_sm.so" "$FLEXRIC_LIB/libkpm_sm.so"
    check_file "librc_sm.so" "$FLEXRIC_LIB/librc_sm.so"
    check_file "libmac_sm.so" "$FLEXRIC_LIB/libmac_sm.so"
    check_file "librlc_sm.so" "$FLEXRIC_LIB/librlc_sm.so"
    check_file "libpdcp_sm.so" "$FLEXRIC_LIB/libpdcp_sm.so"
    check_file "libgtp_sm.so" "$FLEXRIC_LIB/libgtp_sm.so"
    check_file "xapp_kpm_moni" "$XAPP_MONITOR/xapp_kpm_moni"
    check_file "xapp_rc_moni" "$XAPP_MONITOR/xapp_rc_moni"
    check_file "xapp_gtp_mac_rlc_pdcp_moni" "$XAPP_MONITOR/xapp_gtp_mac_rlc_pdcp_moni"

    if [ "$missing" -ne 0 ]; then
        echo ""
        echo "ERRO: artefatos incompletos para os scripts de teste E2."
        echo "      Execute: BUILD_FLEXRIC_TOOLS=1 ./scripts/build_gnb_e2.sh"
        echo "      ou:      ./scripts/build_flexric_tools.sh"
        exit 1
    fi

    echo "OK: todos os artefatos necessários para os testes E2 estão presentes."
}

verify_test_resources

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
echo "  ./scripts/up_core.sh"
echo "  ./scripts/up_e2_lab.sh"
echo ""
echo "Testes E2 (após o lab no ar):"
echo "  ./scripts/test_e2_sm.sh cust"
echo "  ./scripts/test_e2_kpm.sh"
echo "  ./scripts/test_e2_rc_attach.sh"
echo "=========================================="