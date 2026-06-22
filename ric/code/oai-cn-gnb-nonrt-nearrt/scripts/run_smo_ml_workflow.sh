#!/bin/bash
# Trigger one explicit IA/ML decision cycle using the Fase 3 SMO data store.

set -euo pipefail

SMO_API_PORT="${SMO_API_PORT:-18080}"
SMO_API_URL="${SMO_API_URL:-http://127.0.0.1:$SMO_API_PORT}"
LOW_THP="${ML_THROUGHPUT_LOW_KBPS:-5}"
HIGH_PRB="${ML_PRB_HIGH_PCT:-80}"

python3 - "$SMO_API_URL" "$LOW_THP" "$HIGH_PRB" <<'PY'
import json
import statistics
import sys
import urllib.request

api = sys.argv[1].rstrip("/")
low_thp = float(sys.argv[2])
high_prb = float(sys.argv[3])


def get_json(path):
    with urllib.request.urlopen(api + path, timeout=5) as response:
        return json.loads(response.read().decode("utf-8"))


def post_json(path, payload):
    request = urllib.request.Request(
        api + path,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=5) as response:
        return json.loads(response.read().decode("utf-8"))


metrics = get_json("/metrics/kpm?limit=200").get("metrics", [])


def values(name):
    return [float(item["value"]) for item in metrics if item.get("metric") == name]


dl = values("DRB.UEThpDl")
ul = values("DRB.UEThpUl")
prb_ul = values("RRU.PrbTotUl")
features = {
    "samples": len(metrics),
    "avg_dl_kbps": round(statistics.mean(dl), 3) if dl else None,
    "avg_ul_kbps": round(statistics.mean(ul), 3) if ul else None,
    "max_prb_ul_pct": max(prb_ul) if prb_ul else None,
}

if not metrics:
    recommendation = "collect-more-data"
elif features["max_prb_ul_pct"] is not None and features["max_prb_ul_pct"] >= high_prb:
    recommendation = "scale-or-shift-uplink-load"
elif features["avg_dl_kbps"] is not None and features["avg_dl_kbps"] < low_thp:
    recommendation = "investigate-low-downlink-throughput"
elif features["avg_ul_kbps"] is not None and features["avg_ul_kbps"] < low_thp:
    recommendation = "investigate-low-uplink-throughput"
else:
    recommendation = "keep-current-policy"

payload = {
    "status": "completed",
    "recommendation": recommendation,
    "features": features,
    "model": {
        "type": "manual-threshold-baseline",
        "low_throughput_kbps": low_thp,
        "high_prb_pct": high_prb,
    },
}
post_json("/ml/runs", payload)
print(json.dumps(payload, indent=2, sort_keys=True))
PY
