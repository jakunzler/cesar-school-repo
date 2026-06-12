#!/bin/bash
# Detecção de containers RAN ativos (UERANSIM split/standalone, srsRAN).
# Uso: source "$(dirname "${BASH_SOURCE[0]}")/ran-detect.sh"

GNB_CONTAINERS=(ueransim-gnb-containerized ueransim srsran-gnb-containerized)
UE_CONTAINERS=(ueransim-ue-containerized ueransim srsran-ue-containerized)

container_running() {
    docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$1"
}

find_running_gnb() {
    for c in "${GNB_CONTAINERS[@]}"; do
        if container_running "$c"; then
            echo "$c"
            return 0
        fi
    done
    return 1
}

find_running_ue() {
    for c in "${UE_CONTAINERS[@]}"; do
        if container_running "$c"; then
            echo "$c"
            return 0
        fi
    done
    return 1
}

get_ue_tunnel() {
    local ue="$1"
    docker exec "$ue" sh -c "ip -o link show 2>/dev/null | sed -E 's/^[0-9]+: ([^:@]+).*/\\1/' | grep -E 'uesimtun|tun_srs' | head -1" 2>/dev/null || echo ""
}

ue_ping() {
    local ue="$1" host="$2" count="${3:-1}" timeout="${4:-2}"
    local tun
    tun=$(get_ue_tunnel "$ue")
    if [ -n "$tun" ]; then
        docker exec "$ue" ping -c "$count" -W "$timeout" -I "$tun" "$host"
    else
        docker exec "$ue" ping -c "$count" -W "$timeout" "$host"
    fi
}

ue_ping_ok() {
    ue_ping "$@" >/dev/null 2>&1
}
