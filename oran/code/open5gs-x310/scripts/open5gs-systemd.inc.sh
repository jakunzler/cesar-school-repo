#!/usr/bin/env bash
# Shell include (source me): parada/início do Open5GS em hosts sem unit agregado open5gs.service.
# Ordem de subida alinhada ao quickstart (CP antes, UPF por último).

OPEN5GS_META_UNIT="open5gs.service"

# Units típicos do pacote Debian/Ubuntu (5GC + opcionais LTE). Ignorados se não instalados.
OPEN5GS_UNITS_START=(
  open5gs-nrfd
  open5gs-scpd
  open5gs-amfd
  open5gs-smfd
  open5gs-ausfd
  open5gs-udmd
  open5gs-udrd
  open5gs-pcfd
  open5gs-nssfd
  open5gs-bsfd
  open5gs-seppd
  open5gs-upfd
  open5gs-mmed
  open5gs-sgwcd
  open5gs-sgwud
  open5gs-hssd
)

_open5gs_sc() {
  if command -v sudo >/dev/null 2>&1 && [[ "$(id -u)" -ne 0 ]]; then
    sudo systemctl "$@"
  else
    systemctl "$@"
  fi
}

open5gs_unit_loaded() {
  local u="$1"
  systemctl cat --no-pager "$u" >/dev/null 2>&1
}

open5gs_any_running() {
  if open5gs_unit_loaded "${OPEN5GS_META_UNIT}"; then
    systemctl is-active --quiet "${OPEN5GS_META_UNIT}" && return 0
  fi
  local u us
  for u in "${OPEN5GS_UNITS_START[@]}"; do
    us="${u}.service"
    if open5gs_unit_loaded "$us" && systemctl is-active --quiet "$us" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

open5gs_stop_stack() {
  if open5gs_unit_loaded "${OPEN5GS_META_UNIT}"; then
    echo "==> Parando ${OPEN5GS_META_UNIT}" >&2
    _open5gs_sc stop "${OPEN5GS_META_UNIT}" || true
    return 0
  fi
  echo "==> Unit ${OPEN5GS_META_UNIT} não encontrado; parando serviços open5gs-*.service instalados" >&2
  local idx u us
  for ((idx = ${#OPEN5GS_UNITS_START[@]} - 1; idx >= 0; idx--)); do
    u="${OPEN5GS_UNITS_START[idx]}"
    us="${u}.service"
    if open5gs_unit_loaded "$us"; then
      echo "    stop $us" >&2
      _open5gs_sc stop "$us" || true
    fi
  done
}

open5gs_start_stack() {
  if open5gs_unit_loaded "${OPEN5GS_META_UNIT}"; then
    echo "==> Iniciando ${OPEN5GS_META_UNIT}" >&2
    _open5gs_sc start "${OPEN5GS_META_UNIT}" || true
    return 0
  fi
  echo "==> Unit ${OPEN5GS_META_UNIT} não encontrado; iniciando serviços open5gs-*.service instalados" >&2
  local u us
  for u in "${OPEN5GS_UNITS_START[@]}"; do
    us="${u}.service"
    if open5gs_unit_loaded "$us"; then
      echo "    start $us" >&2
      _open5gs_sc start "$us" || true
    fi
  done
}
