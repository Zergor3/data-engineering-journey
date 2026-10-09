import json
import logging
from datetime import datetime, timezone
from pathlib import Path

import os
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

URL = "https://api.open-meteo.com/v1/forecast"
PARAMS = {
    "latitude": -12.04,   # Lima
    "longitude": -77.03,
    "hourly": "temperature_2m,relative_humidity_2m,precipitation",
    "past_days": 7,
    "timezone": "America/Lima",
}
RAW_DIR = Path(os.getenv("RAW_DIR", "data/raw"))


def build_session() -> requests.Session:
    retry = Retry(total=3, backoff_factor=1, status_forcelist=[429, 500, 502, 503, 504])
    session = requests.Session()
    session.mount("https://", HTTPAdapter(max_retries=retry))
    return session


def extract() -> Path:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    resp = build_session().get(URL, params=PARAMS, timeout=30)
    resp.raise_for_status()

    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    path = RAW_DIR / f"weather_lima_{ts}.json"
    path.write_text(json.dumps(resp.json(), ensure_ascii=False, indent=2), encoding="utf-8")
    log.info("Guardado %s (%d bytes)", path, path.stat().st_size)
    return path


if __name__ == "__main__":
    extract()