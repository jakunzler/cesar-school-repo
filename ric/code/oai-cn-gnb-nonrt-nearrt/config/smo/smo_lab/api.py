import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

from .db import connect, dumps, now, rows_to_dicts


def read_json(handler: BaseHTTPRequestHandler) -> dict:
    length = int(handler.headers.get("Content-Length", "0") or "0")
    if length == 0:
        return {}
    raw = handler.rfile.read(length)
    return json.loads(raw.decode("utf-8"))


class SmoHandler(BaseHTTPRequestHandler):
    server_version = "smo-lab/1.0"

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args), flush=True)

    def send_json(self, status: int, payload: dict | list):
        body = json.dumps(payload, indent=2, sort_keys=True).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"
        query = parse_qs(parsed.query)

        if path == "/health":
            self.send_json(200, {"status": "ok", "service": "smo-api"})
            return

        with connect() as conn:
            if path == "/o1/v1/nodes":
                rows = conn.execute("SELECT * FROM nodes ORDER BY node_id").fetchall()
                self.send_json(200, {"nodes": rows_to_dicts(rows)})
                return

            if path == "/ves/v7/events":
                limit = int(query.get("limit", ["50"])[0])
                rows = conn.execute(
                    "SELECT * FROM ves_events ORDER BY id DESC LIMIT ?", (limit,)
                ).fetchall()
                self.send_json(200, {"events": rows_to_dicts(rows)})
                return

            if path == "/metrics/kpm":
                limit = int(query.get("limit", ["100"])[0])
                rows = conn.execute(
                    "SELECT * FROM kpm_metrics ORDER BY id DESC LIMIT ?", (limit,)
                ).fetchall()
                self.send_json(200, {"metrics": rows_to_dicts(rows)})
                return

            if path == "/ml/runs":
                limit = int(query.get("limit", ["20"])[0])
                rows = conn.execute(
                    "SELECT * FROM ml_runs ORDER BY id DESC LIMIT ?", (limit,)
                ).fetchall()
                self.send_json(200, {"runs": rows_to_dicts(rows)})
                return

            if path == "/topology":
                nodes = rows_to_dicts(conn.execute("SELECT * FROM nodes ORDER BY node_id").fetchall())
                events = rows_to_dicts(
                    conn.execute("SELECT * FROM ves_events ORDER BY id DESC LIMIT 10").fetchall()
                )
                self.send_json(200, {"nodes": nodes, "recent_events": events})
                return

            if path == "/openapi":
                self.send_json(200, openapi_doc())
                return

        self.send_json(404, {"error": "not_found", "path": path})

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"

        try:
            payload = read_json(self)
        except Exception as exc:
            self.send_json(400, {"error": "invalid_json", "detail": str(exc)})
            return

        with connect() as conn:
            if path == "/o1/v1/nodes":
                node_id = payload.get("node_id")
                node_type = payload.get("node_type", "unknown")
                status = payload.get("status", "unknown")
                if not node_id:
                    self.send_json(400, {"error": "missing_node_id"})
                    return
                conn.execute(
                    """
                    INSERT INTO nodes(node_id, node_type, status, last_seen, payload)
                    VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT(node_id) DO UPDATE SET
                        node_type=excluded.node_type,
                        status=excluded.status,
                        last_seen=excluded.last_seen,
                        payload=excluded.payload
                    """,
                    (node_id, node_type, status, now(), dumps(payload)),
                )
                conn.commit()
                self.send_json(201, {"status": "stored", "node_id": node_id})
                return

            if path == "/ves/v7/events":
                source = payload.get("sourceName") or payload.get("source") or "unknown"
                event_type = payload.get("eventType") or payload.get("domain") or "event"
                conn.execute(
                    "INSERT INTO ves_events(ts, source, event_type, payload) VALUES (?, ?, ?, ?)",
                    (now(), source, event_type, dumps(payload)),
                )
                conn.commit()
                self.send_json(202, {"status": "accepted", "source": source})
                return

            if path == "/metrics/kpm":
                source = payload.get("source", "kpm")
                metrics = payload.get("metrics", [])
                inserted = 0
                for item in metrics:
                    metric = item.get("metric")
                    value = item.get("value")
                    if metric is None or value is None:
                        continue
                    conn.execute(
                        """
                        INSERT INTO kpm_metrics(ts, source, metric, value, unit, payload)
                        VALUES (?, ?, ?, ?, ?, ?)
                        """,
                        (
                            item.get("ts", now()),
                            source,
                            metric,
                            float(value),
                            item.get("unit", ""),
                            dumps(item),
                        ),
                    )
                    inserted += 1
                conn.commit()
                self.send_json(202, {"status": "accepted", "inserted": inserted})
                return

            if path == "/ml/runs":
                recommendation = payload.get("recommendation", "observe")
                status = payload.get("status", "completed")
                conn.execute(
                    "INSERT INTO ml_runs(ts, status, recommendation, payload) VALUES (?, ?, ?, ?)",
                    (now(), status, recommendation, dumps(payload)),
                )
                conn.commit()
                self.send_json(201, {"status": "stored", "recommendation": recommendation})
                return

        self.send_json(404, {"error": "not_found", "path": path})


def openapi_doc() -> dict:
    return {
        "openapi": "3.0.0",
        "info": {"title": "OAI SMO Lab API", "version": "1.0.0"},
        "paths": {
            "/health": {"get": {"summary": "Health check"}},
            "/o1/v1/nodes": {"get": {"summary": "List O1 nodes"}, "post": {"summary": "Upsert O1 node"}},
            "/ves/v7/events": {"get": {"summary": "List VES events"}, "post": {"summary": "Ingest VES event"}},
            "/metrics/kpm": {"get": {"summary": "List KPM metrics"}, "post": {"summary": "Ingest KPM metrics"}},
            "/ml/runs": {"get": {"summary": "List ML workflow runs"}, "post": {"summary": "Store ML decision"}},
            "/topology": {"get": {"summary": "Topology snapshot"}},
        },
    }


def main():
    host = os.environ.get("SMO_HOST", "0.0.0.0")
    port = int(os.environ.get("SMO_PORT", "8080"))
    server = ThreadingHTTPServer((host, port), SmoHandler)
    print(f"smo-api listening on {host}:{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
