#!/usr/bin/env python3
"""
============================================================================
BANK MARKETING DATA LOADER - BigQuery Upload Script
============================================================================

Descripción:
    Script para descargar datos del UCI ML Repository y cargarlos a BigQuery.

    Funcionalidades:
    - Descarga datos desde ucimlrepo
    - Aplica timestamp de carga para tracking
    - Valida datos antes de cargar
    - Carga a BigQuery con configuración optimizada
    - Manejo robusto de errores

Uso:
    python load_to_bigquery.py --project-id YOUR_PROJECT_ID --dataset raw_bank_marketing

Autor: Analytics Engineering Team
Fecha: 2025-10-23
============================================================================
"""

import argparse
import logging
import sys
from datetime import datetime
from pathlib import Path
from typing import Tuple

import pandas as pd
from google.cloud import bigquery
from google.oauth2 import service_account
from ucimlrepo import fetch_ucirepo

# ============================================================================
# CONFIGURACIÓN DE LOGGING
# ============================================================================
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('data_loading.log')
    ]
)
logger = logging.getLogger(__name__)


# ============================================================================
# CONSTANTES
# ============================================================================
UCI_DATASET_ID = 222  # Bank Marketing dataset ID
TABLE_NAME = 'raw_bank_marketing'
EXPECTED_COLUMNS = [
    'age', 'job', 'marital', 'education', 'default', 'balance',
    'housing', 'loan', 'contact', 'day_of_week', 'month', 'duration',
    'campaign', 'pdays', 'previous', 'poutcome', 'y'
]


# ============================================================================
# FUNCIONES PRINCIPALES
# ============================================================================

def download_bank_marketing_data() -> pd.DataFrame:
    """
    Descarga el dataset Bank Marketing desde UCI ML Repository.

    Returns:
        pd.DataFrame: DataFrame con los datos combinados (features + target)

    Raises:
        Exception: Si hay error en la descarga
    """
    logger.info(f"Descargando dataset Bank Marketing (ID: {UCI_DATASET_ID})...")

    try:
        # Fetch dataset desde UCI
        bank_marketing = fetch_ucirepo(id=UCI_DATASET_ID)

        # Extraer features y target
        X = bank_marketing.data.features
        y = bank_marketing.data.targets

        # Combinar en un solo DataFrame
        df = pd.concat([X, y], axis=1)

        logger.info(f"✓ Dataset descargado exitosamente: {df.shape[0]:,} registros, {df.shape[1]} columnas")

        return df

    except Exception as e:
        logger.error(f"✗ Error al descargar dataset: {str(e)}")
        raise


def validate_data(df: pd.DataFrame) -> Tuple[bool, str]:
    """
    Valida que los datos tengan la estructura esperada.

    Args:
        df: DataFrame a validar

    Returns:
        Tuple[bool, str]: (es_valido, mensaje_error)
    """
    logger.info("Validando estructura de datos...")

    # Validar que existan todas las columnas esperadas
    missing_cols = set(EXPECTED_COLUMNS) - set(df.columns)
    if missing_cols:
        return False, f"Columnas faltantes: {missing_cols}"

    # Validar que no esté vacío
    if len(df) == 0:
        return False, "DataFrame está vacío"

    # Validar tipos de datos básicos
    if df['age'].dtype not in ['int64', 'int32']:
        return False, f"Tipo de dato incorrecto para 'age': {df['age'].dtype}"

    # Validar que la columna target tenga valores válidos
    valid_target_values = {'yes', 'no'}
    unique_targets = set(df['y'].dropna().unique())
    if not unique_targets.issubset(valid_target_values):
        return False, f"Valores inválidos en target 'y': {unique_targets - valid_target_values}"

    logger.info("✓ Validación exitosa")
    return True, ""


def prepare_data_for_bigquery(df: pd.DataFrame) -> pd.DataFrame:
    """
    Prepara el DataFrame para carga en BigQuery.

    Transformaciones:
    - Agrega timestamp de carga
    - Convierte tipos de datos problemáticos
    - Maneja valores nulos de forma consistente

    Args:
        df: DataFrame original

    Returns:
        pd.DataFrame: DataFrame preparado para BigQuery
    """
    logger.info("Preparando datos para BigQuery...")

    # Crear copia para no modificar el original
    df_prep = df.copy()

    # Agregar timestamp de carga (para lineage y auditoría)
    df_prep['_dbt_loaded_at'] = datetime.utcnow()

    # Agregar ID único para cada registro (útil para debugging)
    df_prep['_row_id'] = range(1, len(df_prep) + 1)

    # Convertir columnas categóricas a string explícitamente
    categorical_cols = ['job', 'marital', 'education', 'default', 'housing',
                       'loan', 'contact', 'month', 'poutcome', 'y']

    for col in categorical_cols:
        if col in df_prep.columns:
            # Mantener NaN como None (no convertir a string 'nan')
            df_prep[col] = df_prep[col].astype('object')

    # Asegurar que columnas numéricas sean del tipo correcto
    numeric_cols = ['age', 'balance', 'day_of_week', 'duration', 'campaign', 'pdays', 'previous']
    for col in numeric_cols:
        if col in df_prep.columns:
            df_prep[col] = pd.to_numeric(df_prep[col], errors='coerce')

    logger.info(f"✓ Datos preparados: {len(df_prep):,} registros, {len(df_prep.columns)} columnas")

    # Log de estadísticas de valores nulos
    null_counts = df_prep.isnull().sum()
    if null_counts.sum() > 0:
        logger.warning("Columnas con valores nulos:")
        for col, count in null_counts[null_counts > 0].items():
            pct = (count / len(df_prep)) * 100
            logger.warning(f"  - {col}: {count:,} ({pct:.2f}%)")

    return df_prep


def load_to_bigquery(
    df: pd.DataFrame,
    project_id: str,
    dataset_id: str,
    table_id: str,
    credentials_path: str = None
) -> None:
    """
    Carga el DataFrame a BigQuery.

    Args:
        df: DataFrame a cargar
        project_id: ID del proyecto GCP
        dataset_id: ID del dataset en BigQuery
        table_id: ID de la tabla
        credentials_path: Ruta al archivo de credenciales (opcional)

    Raises:
        Exception: Si hay error en la carga
    """
    logger.info(f"Iniciando carga a BigQuery: {project_id}.{dataset_id}.{table_id}")

    try:
        # Configurar cliente BigQuery
        if credentials_path:
            credentials = service_account.Credentials.from_service_account_file(
                credentials_path,
                scopes=["https://www.googleapis.com/auth/cloud-platform"]
            )
            client = bigquery.Client(credentials=credentials, project=project_id)
        else:
            # Usar Application Default Credentials
            client = bigquery.Client(project=project_id)

        # Referencia completa a la tabla
        table_ref = f"{project_id}.{dataset_id}.{table_id}"

        # Configuración de carga
        job_config = bigquery.LoadJobConfig(
            # Sobrescribir tabla si existe
            write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,

            # Auto-detectar schema
            autodetect=True,

            # Configuración de schema (explícito para control)
            schema=[
                bigquery.SchemaField("_row_id", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("age", "INTEGER"),
                bigquery.SchemaField("job", "STRING"),
                bigquery.SchemaField("marital", "STRING"),
                bigquery.SchemaField("education", "STRING"),
                bigquery.SchemaField("default", "STRING"),
                bigquery.SchemaField("balance", "INTEGER"),
                bigquery.SchemaField("housing", "STRING"),
                bigquery.SchemaField("loan", "STRING"),
                bigquery.SchemaField("contact", "STRING"),
                bigquery.SchemaField("day_of_week", "INTEGER"),
                bigquery.SchemaField("month", "STRING"),
                bigquery.SchemaField("duration", "INTEGER"),
                bigquery.SchemaField("campaign", "INTEGER"),
                bigquery.SchemaField("pdays", "INTEGER"),
                bigquery.SchemaField("previous", "INTEGER"),
                bigquery.SchemaField("poutcome", "STRING"),
                bigquery.SchemaField("y", "STRING"),
                bigquery.SchemaField("_dbt_loaded_at", "TIMESTAMP", mode="REQUIRED"),
            ],
        )

        # Ejecutar carga
        logger.info("Cargando datos a BigQuery...")
        job = client.load_table_from_dataframe(df, table_ref, job_config=job_config)

        # Esperar a que complete el job
        job.result()

        # Verificar carga
        table = client.get_table(table_ref)
        logger.info(f"✓ Carga exitosa: {table.num_rows:,} registros en {table_ref}")

        # Mostrar información de la tabla
        logger.info(f"  - Tamaño: {table.num_bytes / (1024**2):.2f} MB")
        logger.info(f"  - Creada: {table.created}")
        logger.info(f"  - Modificada: {table.modified}")

    except Exception as e:
        logger.error(f"✗ Error al cargar a BigQuery: {str(e)}")
        raise


def main():
    """Función principal que orquesta el proceso de carga."""

    # ========================================================================
    # PARSEAR ARGUMENTOS
    # ========================================================================
    parser = argparse.ArgumentParser(
        description='Carga datos de Bank Marketing a BigQuery',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos de uso:

  # Usando Application Default Credentials
  python load_to_bigquery.py --project-id my-project --dataset raw_data

  # Usando service account
  python load_to_bigquery.py --project-id my-project --dataset raw_data \\
      --credentials /path/to/key.json

  # Especificar nombre de tabla custom
  python load_to_bigquery.py --project-id my-project --dataset raw_data \\
      --table custom_table_name
        """
    )

    parser.add_argument(
        '--project-id',
        required=True,
        help='GCP Project ID'
    )

    parser.add_argument(
        '--dataset',
        required=True,
        help='BigQuery dataset ID'
    )

    parser.add_argument(
        '--table',
        default=TABLE_NAME,
        help=f'BigQuery table name (default: {TABLE_NAME})'
    )

    parser.add_argument(
        '--credentials',
        help='Path to service account key JSON file (optional)'
    )

    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Download and validate data without loading to BigQuery'
    )

    args = parser.parse_args()

    # ========================================================================
    # EJECUTAR PROCESO
    # ========================================================================
    try:
        logger.info("="*80)
        logger.info("BANK MARKETING DATA LOADER - INICIO")
        logger.info("="*80)

        # Paso 1: Descargar datos
        df = download_bank_marketing_data()

        # Paso 2: Validar datos
        is_valid, error_msg = validate_data(df)
        if not is_valid:
            logger.error(f"✗ Validación fallida: {error_msg}")
            sys.exit(1)

        # Paso 3: Preparar datos
        df_prepared = prepare_data_for_bigquery(df)

        # Paso 4: Cargar a BigQuery (si no es dry-run)
        if args.dry_run:
            logger.info("DRY-RUN: Saltando carga a BigQuery")
            logger.info(f"Preview de datos preparados:\n{df_prepared.head()}")
        else:
            load_to_bigquery(
                df=df_prepared,
                project_id=args.project_id,
                dataset_id=args.dataset,
                table_id=args.table,
                credentials_path=args.credentials
            )

        logger.info("="*80)
        logger.info("✓ PROCESO COMPLETADO EXITOSAMENTE")
        logger.info("="*80)

    except Exception as e:
        logger.error("="*80)
        logger.error(f"✗ ERROR FATAL: {str(e)}")
        logger.error("="*80)
        sys.exit(1)


if __name__ == "__main__":
    main()
