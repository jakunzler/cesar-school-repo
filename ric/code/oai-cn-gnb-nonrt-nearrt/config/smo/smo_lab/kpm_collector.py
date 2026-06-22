import os
import re
import time
from pathlib import Path

from .http_client import post_json


KPM_RE = re.compile(r"^(?P<metric>[A-Za-z0-9_.]+)\s*=\s*(?P<value>-?\d+(?:\.\d+)?)\s*\[(?P<unit>[^\]]+)\]")


def parse_metrics(path: Path, offset: int):
    if not path.exists():
        return offset, []
    size = path.stat().st_size
    if size < offset:
        offset = 0
    metrics = []
    with path.open("r", errors="ignore") as handle:
        handle.seek(offset)
        for line in handle:
            match = KPM_RE.search(line.strip())
            if not match:
                continue
            metrics.append(
                {
                    "metric": match.group("metric"),
                    "value": float(match.group("value")),
                    "unit": match.group("unit"),
                    "ts": time.time(),
                    "line": line.strip(),
                }
            )
        offset = handle.tell()
    return offset, metrics


def main():
    api = os.environ.get("SMO_API_URL", "http://smo-api:8080").rstrip("/")
    interval = int(os.environ.get("KPM_POLL_INTERVAL", "5"))
    files = [
        Path(item)
        for item in os.environ.get("KPM_LOG_FILES", "").split(",")
        if item.strip()
    ]
    offsets = {str(path): 0 for path in files}
    print("watching KPM logs: " + ", ".join(str(path) for path in files), flush=True)

    while True:
        for path in files:
            offset, metrics = parse_metrics(path, offsets.get(str(path), 0))
            offsets[str(path)] = offset
            if metrics:
                payload = {"source": path.name, "metrics": metrics}
                result = post_json(f"{api}/metrics/kpm", payload)
                print(f"stored {result.get('inserted', 0)} KPM metrics from {path.name}", flush=True)
        time.sleep(interval)


if __name__ == "__main__":
    main()
