"""DAG de Olist: CSV -> staging -> data warehouse dimensional -> validaciones."""
# pyright: reportMissingImports=false
from datetime import datetime, timedelta
from pathlib import Path

from airflow.sdk import DAG
from airflow.providers.standard.operators.python import PythonOperator

SQL_DIR = Path("/opt/airflow/sql")


def _load_staging() -> None:
    from load_olist import run

    run()


def _run_sql(filename: str) -> None:
    from run_sql import run_sql_file

    run_sql_file(SQL_DIR / filename)


with DAG(
    dag_id="olist_pipeline",
    description="Olist: staging -> dw (dimensiones y hechos) -> validaciones",
    start_date=datetime(2026, 10, 1),
    schedule=None,          # dataset estatico: se lanza a mano
    catchup=False,
    default_args={"retries": 2, "retry_delay": timedelta(minutes=1)},
    tags=["olist", "mes2"],
) as dag:
    load_staging = PythonOperator(
        task_id="load_staging",
        python_callable=_load_staging,
    )

    create_dw_schema = PythonOperator(
        task_id="create_dw_schema",
        python_callable=_run_sql,
        op_args=["01_dw_ddl.sql"],
    )

    load_dw = PythonOperator(
        task_id="load_dw",
        python_callable=_run_sql,
        op_args=["02_dw_load.sql"],
    )

    # Sin reintentos: si los datos no cuadran, reintentar no los arregla.
    validate = PythonOperator(
        task_id="validate",
        python_callable=_run_sql,
        op_args=["03_validations.sql"],
        retries=0,
    )

    load_staging >> create_dw_schema >> load_dw >> validate