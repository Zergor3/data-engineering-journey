import json
import logging
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

DB_URL = "postgresql+psycopg2://de:de@localhost:5432/warehouse"
RAW_DIR = Path("data/raw")
TABLE = "weather_hourly"
SCHEMA = "staging"


def latest_raw_file() -> Path:
    files = sorted(RAW_DIR.glob("weather_lima_*.json"))
    if not files:
        raise FileNotFoundError(f"No hay archivos en {RAW_DIR}")
    return files[-1]  # el timestamp en el nombre hace que el orden alfabético sea cronológico


def to_dataframe(path: Path) -> pd.DataFrame:
    data = json.loads(path.read_text(encoding="utf-8"))

    df = pd.DataFrame(data["hourly"])  # las listas paralelas se vuelven columnas
    df = df.rename(columns={
        "time": "observed_at",
        "temperature_2m": "temperature_c",
        "relative_humidity_2m": "humidity_pct",
        "precipitation": "precipitation_mm",
    })

    df["observed_at"] = pd.to_datetime(df["observed_at"])  # hora local de Lima, sin zona
    df = df.astype({
        "temperature_c": "float64",
        "humidity_pct": "float64",
        "precipitation_mm": "float64",
    })

    # Metadatos de trazabilidad
    df["latitude"] = data["latitude"]
    df["longitude"] = data["longitude"]
    df["_source_file"] = path.name
    df["_loaded_at"] = pd.Timestamp.now(tz="UTC")
    return df


def load(df: pd.DataFrame, engine: Engine) -> None:
    with engine.begin() as conn:  # transacción: o se hace todo o nada
        conn.execute(text(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA}"))
        # Idempotencia: si ya cargaste este archivo, borra sus filas antes de reinsertar
        exists = conn.execute(
            text("SELECT to_regclass(:t)"), {"t": f"{SCHEMA}.{TABLE}"}
        ).scalar()
        if exists:
            conn.execute(
                text(f"DELETE FROM {SCHEMA}.{TABLE} WHERE _source_file = :f"),
                {"f": df["_source_file"].iloc[0]},
            )
        df.to_sql(TABLE, conn, schema=SCHEMA, if_exists="append",
                  index=False, method="multi", chunksize=1000)
    log.info("Cargadas %d filas en %s.%s", len(df), SCHEMA, TABLE)


if __name__ == "__main__":
    path = latest_raw_file()
    log.info("Procesando %s", path)
    df = to_dataframe(path)
    log.info("Shape: %s | nulos:\n%s", df.shape, df.isna().sum())
    load(df, create_engine(DB_URL))