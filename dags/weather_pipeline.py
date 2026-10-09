"""DAG del pipeline del clima: API -> JSON crudo -> pandas -> staging.weather_hourly."""
# pyright: reportMissingImports=false
from datetime import datetime, timedelta

from airflow.sdk import DAG
from airflow.providers.standard.operators.python import PythonOperator


# Los imports pesados (pandas, sqlalchemy) van DENTRO de las funciones:
# el dag-processor lee este archivo constantemente y debe cargarse rápido.
def _extract() -> str:
    from extract_weather import extract

    return str(extract())


def _transform_load() -> None:
    from transform_load_weather import run

    run()


default_args = {
    "retries": 3,                         # reintenta si la API falla
    "retry_delay": timedelta(minutes=2),  # espera entre reintentos
}

with DAG(
    dag_id="weather_pipeline",
    description="Extrae el clima de Lima y lo carga a staging en Postgres",
    start_date=datetime(2026, 10, 1),
    schedule="@daily",                    # una vez al día (a las 00:00 UTC)
    catchup=False,                        # no ejecutar las fechas pasadas
    default_args=default_args,
    tags=["clima", "mes2"],
) as dag:
    extract_weather = PythonOperator(
        task_id="extract_weather",
        python_callable=_extract,
    )

    transform_load_weather = PythonOperator(
        task_id="transform_load_weather",
        python_callable=_transform_load,
    )

    extract_weather >> transform_load_weather