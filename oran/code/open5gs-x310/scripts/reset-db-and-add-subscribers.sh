#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=open5gs-systemd.inc.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/open5gs-systemd.inc.sh"

DB_NAME="open5gs"
BACKUP_BASE="${BACKUP_BASE:-${ROOT_DIR}/db-backups}"
DB_DUMP_SCRIPT="${SCRIPT_DIR}/dump-restore-open5gs-db.sh"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1" >&2
    exit 1
  }
}

require_cmd mongosh
require_cmd systemctl
command -v sudo >/dev/null 2>&1 || true

IMSI_01="001010000000001"
IMSI_02="001010000000002"

# Dados fornecidos pelo usuário
K="82E9053A1882085FF2C020359938DAE9"
OPC_OR_OP="BFD5771AAF4F6728E9BC6EF2C2533BDB" # opType: "OPC" => salvar como "opc"
OP_TYPE="OPC" # mantido para deixar claro o mapeamento
AMF="8000"

# Network slice: só SST (sem SD), como em core/config/amf.yaml e SMF/NSSF
SST="1"
SVC_NAME="internet"
QOS_INDEX="7"
ARP_PRIORITY="7"
PRE_EMPTION_CAPABILITY="1"
PRE_EMPTION_VULNERABILITY="1"
SESSION_TYPE="3"

TOP_AMBR_UP_VALUE="1"
TOP_AMBR_DN_VALUE="1"
TOP_AMBR_UNIT="3"

SLICE_AMBR_UP_VALUE="10"
SLICE_AMBR_DN_VALUE="50"
SLICE_AMBR_UNIT="2"

# (Opcional) IMEISV só pra manter compatibilidade com o schema atual do open5gs.
IMEISV_01="3591723910743902"
IMEISV_02="3591723910738202"

get_existing_sqn() {
  local imsi="$1"
  # Se não existir, devolve -1. Se existir, devolve número como string (sem "Long(...)").
  mongosh "$DB_NAME" --quiet --eval "
    const d = db.subscribers.findOne({imsi: '${imsi}'}, {security: 1, _id: 0});
    if (!d || !d.security || d.security.sqn === undefined || d.security.sqn === null) print('-1');
    else print(d.security.sqn.toString());
  " 2>/dev/null | tr -d '\r' | tr -d '\n' || true
}

echo "==> Reset DB ($DB_NAME) e adicionar subscribers (limpo e idempotente)"
echo "==> Criando dump de segurança antes de apagar o banco"
BACKUP_DIR="$("$DB_DUMP_SCRIPT" dump --out "$BACKUP_BASE")"
echo "==> Dump salvo em: $BACKUP_DIR"

open5gs_stop_stack

SQN_01="$(get_existing_sqn "$IMSI_01" || echo "-1")"
SQN_02="$(get_existing_sqn "$IMSI_02" || echo "-1")"

echo "==> Limpando coleções: subscribers, accounts, sessions"
mongosh "$DB_NAME" --quiet --eval "
  const cols = ['subscribers','accounts','sessions'];
  for (const c of cols) {
    try { db.getCollection(c).drop(); } catch (e) {}
  }
"

echo "==> Inserindo subscriber 01 (IMSI: $IMSI_01)"
JS_SQN_01="$SQN_01"
mongosh "$DB_NAME" --quiet --eval "
  const imsi='${IMSI_01}';
  const session=[{
    name: '${SVC_NAME}',
    type: ${SESSION_TYPE},
    pcc_rule: [],
    qos: {
      index: ${QOS_INDEX},
      arp: {
        priority_level: ${ARP_PRIORITY},
        pre_emption_capability: ${PRE_EMPTION_CAPABILITY},
        pre_emption_vulnerability: ${PRE_EMPTION_VULNERABILITY}
      }
    },
    ambr: {
      uplink: { value: ${SLICE_AMBR_UP_VALUE}, unit: ${SLICE_AMBR_UNIT} },
      downlink: { value: ${SLICE_AMBR_DN_VALUE}, unit: ${SLICE_AMBR_UNIT} }
    }
  }];
  const slice=[{ sst: ${SST}, default_indicator: true, session: session }];

  const security = {
    k: '${K}',
    amf: '${AMF}',
    op: null,
    opc: '${OPC_OR_OP}'
  };
  // Mantém o SQN existente (se houver) para reduzir chance de rejeição por des-sincronização.
  if (${JS_SQN_01} !== -1 && ${JS_SQN_01} !== undefined) security.sqn = Long(${JS_SQN_01});

  db.subscribers.insertOne({
    schema_version: 1,
    imsi,
    msisdn: [],
    imeisv: '${IMEISV_01}',
    mme_host: [],
    mme_realm: [],
    purge_flag: [],
    access_restriction_data: 32,
    subscriber_status: 0,
    operator_determined_barring: 0,
    network_access_mode: 0,
    subscribed_rau_tau_timer: 12,
    security,
    ambr: {
      uplink: { value: ${TOP_AMBR_UP_VALUE}, unit: ${TOP_AMBR_UNIT} },
      downlink: { value: ${TOP_AMBR_DN_VALUE}, unit: ${TOP_AMBR_UNIT} }
    },
    slice
  });
"

echo "==> Inserindo subscriber 02 (IMSI: $IMSI_02)"
JS_SQN_02="$SQN_02"
mongosh "$DB_NAME" --quiet --eval "
  const imsi='${IMSI_02}';
  const session=[{
    name: '${SVC_NAME}',
    type: ${SESSION_TYPE},
    pcc_rule: [],
    qos: {
      index: ${QOS_INDEX},
      arp: {
        priority_level: ${ARP_PRIORITY},
        pre_emption_capability: ${PRE_EMPTION_CAPABILITY},
        pre_emption_vulnerability: ${PRE_EMPTION_VULNERABILITY}
      }
    },
    ambr: {
      uplink: { value: ${SLICE_AMBR_UP_VALUE}, unit: ${SLICE_AMBR_UNIT} },
      downlink: { value: ${SLICE_AMBR_DN_VALUE}, unit: ${SLICE_AMBR_UNIT} }
    }
  }];
  const slice=[{ sst: ${SST}, default_indicator: true, session: session }];

  const security = {
    k: '${K}',
    amf: '${AMF}',
    op: null,
    opc: '${OPC_OR_OP}'
  };
  // Mantém o SQN existente (se houver) para reduzir chance de rejeição por des-sincronização.
  if (${JS_SQN_02} !== -1 && ${JS_SQN_02} !== undefined) security.sqn = Long(${JS_SQN_02});

  db.subscribers.insertOne({
    schema_version: 1,
    imsi,
    msisdn: [],
    imeisv: '${IMEISV_02}',
    mme_host: [],
    mme_realm: [],
    purge_flag: [],
    access_restriction_data: 32,
    subscriber_status: 0,
    operator_determined_barring: 0,
    network_access_mode: 0,
    subscribed_rau_tau_timer: 12,
    security,
    ambr: {
      uplink: { value: ${TOP_AMBR_UP_VALUE}, unit: ${TOP_AMBR_UNIT} },
      downlink: { value: ${TOP_AMBR_DN_VALUE}, unit: ${TOP_AMBR_UNIT} }
    },
    slice
  });
"

echo "==> Validando inserção"
mongosh "$DB_NAME" --quiet --eval "
  const c1 = db.subscribers.countDocuments({imsi: '${IMSI_01}'});
  const c2 = db.subscribers.countDocuments({imsi: '${IMSI_02}'});
  print(JSON.stringify({imsi_01_count: c1, imsi_02_count: c2}));
"

echo "==> Web UI: recriar utilizador padrão admin / 1423 (coleção accounts)"
mongosh "$DB_NAME" --quiet "${SCRIPT_DIR}/mongo-webui-default-admin.js"

echo "==> Subindo Open5GS novamente (meta unit ou serviços individuais)"
open5gs_start_stack

echo "==> OK. Aguarde alguns segundos e verifique os logs do AMF para confirmar que não há rejeição por subscriber/slice."
echo "    Exemplos:"
echo "    - sudo tail -f /var/log/open5gs/amf.log"

