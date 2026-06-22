import os
import statistics
import time

from .http_client import get_json, post_json


def latest_values(metrics, name):
    return [float(item["value"]) for item in metrics if item.get("metric") == name]


def decide(metrics, low_throughput_kbps: float, high_prb_pct: float) -> dict:
    dl = latest_values(metrics, "DRB.UEThpDl")
    ul = latest_values(metrics, "DRB.UEThpUl")
    prb_ul = latest_values(metrics, "RRU.PrbTotUl")
    delay = latest_values(metrics, "DRB.RlcSduDelayDl")

    if not metrics:
        return {
            "status": "waiting_for_data",
            "recommendation": "collect-more-data",
            "features": {},
        }

    features = {
        "samples": len(metrics),
        "avg_dl_kbps": round(statistics.mean(dl), 3) if dl else None,
        "avg_ul_kbps": round(statistics.mean(ul), 3) if ul else None,
        "max_prb_ul_pct": max(prb_ul) if prb_ul else None,
        "avg_rlc_delay_us": round(statistics.mean(delay), 3) if delay else None,
    }

    if features["max_prb_ul_pct"] is not None and features["max_prb_ul_pct"] >= high_prb_pct:
        recommendation = "scale-or-shift-uplink-load"
    elif features["avg_dl_kbps"] is not None and features["avg_dl_kbps"] < low_throughput_kbps:
        recommendation = "investigate-low-downlink-throughput"
    elif features["avg_ul_kbps"] is not None and features["avg_ul_kbps"] < low_throughput_kbps:
        recommendation = "investigate-low-uplink-throughput"
    else:
        recommendation = "keep-current-policy"

    return {
        "status": "completed",
        "recommendation": recommendation,
        "features": features,
        "model": {
            "type": "threshold-baseline",
            "low_throughput_kbps": low_throughput_kbps,
            "high_prb_pct": high_prb_pct,
        },
    }


def main():
    api = os.environ.get("SMO_API_URL", "http://smo-api:8080").rstrip("/")
    interval = int(os.environ.get("ML_WORKFLOW_INTERVAL", "20"))
    low_throughput = float(os.environ.get("ML_THROUGHPUT_LOW_KBPS", "5"))
    high_prb = float(os.environ.get("ML_PRB_HIGH_PCT", "80"))

    while True:
        payload = get_json(f"{api}/metrics/kpm?limit=200")
        result = decide(payload.get("metrics", []), low_throughput, high_prb)
        post_json(f"{api}/ml/runs", result)
        print(f"ML workflow: {result['status']} -> {result['recommendation']}", flush=True)
        time.sleep(interval)


if __name__ == "__main__":
    main()
