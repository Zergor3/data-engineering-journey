import logging
from pathlib import Path

import os
import pandas as pd
from sqlalchemy import create_engine, text

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

DB_URL = os.getenv("DB_URL", "postgresql+psycopg2://de:de@localhost:5432/warehouse")
SRC_DIR = Path(os.getenv("OLIST_DIR", "data/olist"))
SCHEMA = "staging"
PREFIX = "olist_"          # tablas: staging.olist_orders, staging.olist_customers, ...
CHUNK = 50_000


def table_name(path: Path) -> str:
    name = path.stem.removesuffix("_dataset")
    return name if name.startswith("olist_") else f"{PREFIX}{name}"


def load_csv(path: Path, engine) -> int:
    table = table_name(path)
    total = 0
    first = True
    # dtype=str: la capa staging guarda el dato tal como llega; los tipos se castean en el DW
    for chunk in pd.read_csv(path, dtype=str, encoding="utf-8", chunksize=CHUNK):
        chunk["_source_file"] = path.name
        chunk.to_sql(
            table, engine, schema=SCHEMA,
            if_exists="replace" if first else "append",  # replace = idempotente
            index=False, method="multi", chunksize=5_000,
        )
        first = False
        total += len(chunk)
    log.info("%-40s %8d filas", f"{SCHEMA}.{table}", total)
    return total


def run() -> None:
    engine = create_engine(DB_URL)
    with engine.begin() as conn:
        conn.execute(text(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA}"))

    files = sorted(SRC_DIR.glob("*.csv"))
    if not files:
        raise FileNotFoundError(f"No hay CSV en {SRC_DIR}")
    for f in files:
        load_csv(f, engine)


if __name__ == "__main__":
    run()