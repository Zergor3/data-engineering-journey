FROM apache/airflow:3.3.2

# Dependencias extra que usan tus scripts (pandas, etc.)
COPY requirements-airflow.txt /tmp/requirements-airflow.txt
RUN pip install --no-cache-dir -r /tmp/requirements-airflow.txt