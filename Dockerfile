# Dockerfile para Bank Marketing DBT
# Usar Python 3.10 por compatibilidad con google-cloud-bigquery
FROM python:3.10-slim

# Variables de entorno
ENV PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Crear directorio de trabajo
WORKDIR /app

# Copiar requirements
COPY data_loading/requirements.txt /app/requirements.txt

# Instalar dependencias Python
# Usar dbt 1.7 que tiene mejor compatibilidad con versiones recientes
RUN pip install --no-cache-dir \
    dbt-core==1.7.17 \
    dbt-bigquery==1.7.9 \
    && pip install --no-cache-dir -r requirements.txt

# Copiar proyecto
COPY . /app

# Punto de entrada
CMD ["/bin/bash"]
