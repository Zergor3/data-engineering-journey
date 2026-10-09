# pyright: reportMissingImports=false
from datetime import datetime
from airflow.sdk import DAG
from airflow.providers.standard.operators.bash import BashOperator

with DAG(
    dag_id="ejemplo",
    start_date=datetime(2026, 10, 1),
    schedule="@daily",
    catchup=False,
) as dag:
    t1 = BashOperator(task_id="extraer", bash_command="echo extrayendo")
    t2 = BashOperator(task_id="cargar", bash_command="echo cargando")

    t1 >> t2   # t2 solo corre si t1 terminó bien