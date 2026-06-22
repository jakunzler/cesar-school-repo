import os
import random
import time

from .http_client import post_json


def main():
    api = os.environ.get("SMO_API_URL", "http://smo-api:8080").rstrip("/")
    interval = int(os.environ.get("O1_SIM_INTERVAL", "15"))
    nodes = [
        {"node_id": "odu-sim-001", "node_type": "O-DU", "plmn": "20895", "status": "unlocked"},
        {"node_id": "oru-sim-001", "node_type": "O-RU", "plmn": "20895", "status": "unlocked"},
        {"node_id": "near-rt-ric-lab", "node_type": "nearRT-RIC", "plmn": "20895", "status": "available"},
    ]

    counter = 0
    while True:
        for node in nodes:
            payload = dict(node)
            payload["cell_id"] = "00000e00"
            payload["interface"] = "O1"
            post_json(f"{api}/o1/v1/nodes", payload)

        event = {
            "domain": "measurement",
            "eventType": "O1_HEARTBEAT",
            "sourceName": "odu-sim-001",
            "sequence": counter,
            "measurements": {
                "availability": 1,
                "temperature_c": round(40 + random.random() * 4, 2),
                "tx_power_dbm": round(18 + random.random() * 2, 2),
            },
        }
        post_json(f"{api}/ves/v7/events", event)
        print(f"published O1 topology and VES event #{counter}", flush=True)
        counter += 1
        time.sleep(interval)


if __name__ == "__main__":
    main()
