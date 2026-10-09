"""DAG de Olist con dbt: CSV -> staging (Airflow) -> dw (dbt build, con tests)."""
# pyright: reportMissingImports=false
from datetime import datetime, timedelta

from airflow.sdk import DAG
from airflow.providers.standard.operators.bash import BashOperator
from airflow.providers.standard.operators.python import PythonOperator


def _load_staging() -> None:
    from load_olist import run

    run()


# --target-path y --log-path van a /tmp: evita escribir en la carpeta montada desde Windows.
DBT_BUILD = (
    "cd /opt/airflow/dbt/olist_dw && "
    "/opt/airflow/dbt_venv/bin/dbt build "
    "--profiles-dir . "
    "--target-path /tmp/dbt_target "
    "--log-path /tmp/dbt_logs"
)

with DAG(
    dag_id="olist_dbt_pipeline",
    description="Olist: staging (Python) -> modelos y tests con dbt",
    start_date=datetime(2026, 10, 1),
    schedule=None,
    catchup=False,
    default_args={"retries": 2, "retry_delay": timedelta(minutes=1)},
    tags=["olist", "dbt", "mes2"],
) as dag:
    load_staging = PythonOperator(
        task_id="load_staging",
        python_callable=_load_staging,
    )

    # Sin reintentos: si un test falla, volver a ejecutar no cambia los datos.
    # dbt termina con codigo distinto de 0 cuando un modelo o un test falla,
    # y BashOperator marca la tarea como fallida.
    dbt_build = BashOperator(
        task_id="dbt_build",
        bash_command=DBT_BUILD,
        retries=0,
    )

    load_staging >> dbt_build