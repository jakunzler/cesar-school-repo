import json
import os
import sqlite3
import time
from pathlib import Path


def db_path() -> str:
    return os.environ.get("SMO_DB_PATH", "/data/smo-lab.db")


def connect() -> sqlite3.Connection:
    path = Path(db_path())
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    init(conn)
    return conn


def init(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS nodes (
            node_id TEXT PRIMARY KEY,
            node_type TEXT NOT NULL,
            status TEXT NOT NULL,
            last_seen REAL NOT NULL,
            payload TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS ves_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts REAL NOT NULL,
            source TEXT NOT NULL,
            event_type TEXT NOT NULL,
            payload TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS kpm_metrics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts REAL NOT NULL,
            source TEXT NOT NULL,
            metric TEXT NOT NULL,
            value REAL NOT NULL,
            unit TEXT NOT NULL,
            payload TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS ml_runs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts REAL NOT NULL,
            status TEXT NOT NULL,
            recommendation TEXT NOT NULL,
            payload TEXT NOT NULL
        );
        """
    )
    conn.commit()


def now() -> float:
    return time.time()


def dumps(payload) -> str:
    return json.dumps(payload, sort_keys=True, separators=(",", ":"))


def rows_to_dicts(rows) -> list[dict]:
    return [dict(row) for row in rows]
