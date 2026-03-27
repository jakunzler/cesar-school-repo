#!/usr/bin/env bash
set -euo pipefail

# Para todos os serviços Open5GS cujos unit files aparecem em systemd.

if ! command -v systemctl >/dev/null 2>&1; then
  echo "Erro: systemctl não encontrado no PATH." >&2
  exit 1
fi

mapfile -t units < <(systemctl list-unit-files --no-legend | awk '/open5gs/ { print $1 }')

if [[ ${#units[@]} -eq 0 ]]; then
  echo "Nenhum unit file open5gs listado por systemctl list-unit-files."
  echo "Nada a parar."
  exit 0
fi

echo "Unidades Open5GS que serão paradas (${#units[@]}):"
printf '  - %s\n' "${units[@]}"
echo

ok=0
fail=0
for svc in "${units[@]}"; do
  printf 'Parando %s ... ' "$svc"
  if sudo systemctl stop "$svc"; then
    echo "OK"
    ok=$((ok + 1))
  else
    echo "FALHOU"
    fail=$((fail + 1))
  fi
done

echo
echo "Resumo: ${ok} parado(s) com sucesso, ${fail} falha(s)."
echo "Estado atual (ActiveState):"
for svc in "${units[@]}"; do
  state=$(systemctl show -p ActiveState --value "$svc" 2>/dev/null || echo "?")
  sub=$(systemctl show -p SubState --value "$svc" 2>/dev/null || echo "")
  if [[ -n "$sub" && "$sub" != "$state" ]]; then
    printf '  %-45s %s (%s)\n' "$svc" "$state" "$sub"
  else
    printf '  %-45s %s\n' "$svc" "$state"
  fi
done

if [[ "$fail" -gt 0 ]]; then
  exit 1
fi
