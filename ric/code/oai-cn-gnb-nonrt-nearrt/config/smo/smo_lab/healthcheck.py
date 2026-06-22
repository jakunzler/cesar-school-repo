import sys

from .http_client import get_json


def main():
    url = sys.argv[1]
    payload = get_json(url, timeout=2)
    if payload.get("status") != "ok":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
