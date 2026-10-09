FROM apache/airflow:3.3.2

# Dependencias extra que usan tus scripts (pandas, etc.)
COPY requirements-airflow.txt /tmp/requirements-airflow.txt
RUN pip install --no-cache-dir -r /tmp/requirements-airflow.txt

# dbt en un entorno virtual aparte: sus dependencias no deben chocar con las de Airflow.
# Versiones fijadas a las mismas que usas en local.
RUN python -m venv /opt/airflow/dbt_venv \
    && /opt/airflow/dbt_venv/bin/pip install --no-cache-dir \
        dbt-core==1.12.5 dbt-postgres==1.11.0