# Guía de Setup

Cómo levantar este proyecto desde cero.

## Lo que necesitas

- Cuenta de Google Cloud Platform (free tier funciona)
- Python 3.10+
- gcloud CLI instalado
- 30 minutos

## Paso 1: Setup Local (5 min)

```bash
# Clonar
git clone <repo-url>
cd bank-marketing-dbt

# Virtual environment
python3 -m venv venv
source venv/bin/activate  # En Windows: venv\Scripts\activate

# Instalar DBT
pip install dbt-core==1.7.17 dbt-bigquery==1.7.9

# Instalar deps para carga de datos
cd data_loading
pip install -r requirements.txt
cd ..
```

## Paso 2: Google Cloud (10 min)

### Autenticar

```bash
gcloud auth login
gcloud auth application-default login
```

### Crear/seleccionar proyecto

```bash
# Ver proyectos
gcloud projects list

# Crear uno nuevo (opcional)
gcloud projects create bank-marketing-demo-001 --name="Bank Marketing"

# Seleccionar
gcloud config set project bank-marketing-demo-001
```

### Crear dataset en BigQuery

```bash
# Solo necesitas crear el dataset raw, los demás se crean solos
bq mk --dataset --location=US bank-marketing-demo-001:bank_marketing_dev
```

## Paso 3: Configurar DBT (3 min)

Crear `~/.dbt/profiles.yml`:

```yaml
bank_marketing:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: bank-marketing-demo-001  # Tu proyecto aquí
      dataset: bank_marketing_dev
      location: US
      threads: 4
      timeout_seconds: 300
```

Verificar conexión:

```bash
cd dbt_project
dbt debug

# Debe decir: Connection test: OK connection ok
```

## Paso 4: Cargar Datos (5 min)

```bash
cd ../data_loading

# El script descarga el dataset de UCI y lo sube a BigQuery
python load_to_bigquery.py

# Deberías ver:
# ✓ Downloaded 45,211 records
# ✓ Loaded to bank_marketing_dev.raw_bank_marketing
```

Verificar que se cargaron:

```bash
bq query --use_legacy_sql=false \
  'SELECT COUNT(*) FROM `bank-marketing-demo-001.bank_marketing_dev.raw_bank_marketing`'

# Debe retornar 45211
```

## Paso 5: Ejecutar DBT (5 min)

```bash
cd ../dbt_project

# Instalar paquetes (dbt-utils, dbt-expectations, etc)
dbt deps

# Ejecutar modelos
dbt run

# Salida esperada:
# 1 of 2 OK created sql view model bank_marketing_dev_staging.staging_bank_marketing
# 2 of 2 OK created sql table model bank_marketing_dev_marts.kpi_bank_marketing
# Done. PASS=2 WARN=0 ERROR=0
```

Esto crea:
- **staging_bank_marketing**: View con 45K registros limpios (32 columnas)
- **kpi_bank_marketing**: Tabla con 35K registros de KPIs agregados (47 columnas)

## Paso 6: Correr Tests (2 min)

```bash
dbt test

# Debe pasar los 29 tests:
# Done. PASS=29 WARN=0 ERROR=0
```

Si falla algún test:

```bash
# Ver detalles
dbt test --store-failures

# Los registros que fallan se guardan en BigQuery para debugging
bq query --use_legacy_sql=false \
  'SELECT * FROM `bank-marketing-demo-001.bank_marketing_dev.test_*` LIMIT 10'
```

## Paso 7: Ver la Documentación (1 min)

```bash
dbt docs generate
dbt docs serve

# Se abre http://localhost:8080
```

En las docs puedes ver:
- Diagramas de lineage (cómo fluyen los datos)
- Descripción de cada columna
- Qué tests tiene cada modelo
- Queries compiladas

## Verificar que Todo Funcionó

Corre estas queries en BigQuery console:

```sql
-- 1. Conversion rate promedio (debe ser ~11.7%)
SELECT AVG(conversion_rate_pct) as avg_conversion
FROM `bank-marketing-demo-001.bank_marketing_dev_marts.kpi_bank_marketing`;

-- 2. Top 5 segmentos que mejor convierten
SELECT
  age_segment,
  AVG(conversion_rate_pct) as conversion,
  SUM(total_contacts) as contacts
FROM `bank-marketing-demo-001.bank_marketing_dev_marts.kpi_bank_marketing`
GROUP BY age_segment
ORDER BY conversion DESC
LIMIT 5;

-- 3. Conversión por mes
SELECT
  contact_month,
  AVG(conversion_rate_pct) as conversion
FROM `bank-marketing-demo-001.bank_marketing_dev_marts.kpi_bank_marketing`
GROUP BY contact_month
ORDER BY conversion DESC;
```

Si estos queries funcionan y retornan datos razonables, todo está OK.

## Comandos Útiles

```bash
# Ejecutar modelo específico
dbt run --select staging_bank_marketing

# Ejecutar modelo y todo lo que depende de él
dbt run --select staging_bank_marketing+

# Tests de un solo modelo
dbt test --select kpi_bank_marketing

# Ver SQL compilado sin ejecutar
dbt compile
cat target/compiled/bank_marketing_analytics/models/marts/kpi_bank_marketing.sql

# Recrear todo desde cero
dbt run --full-refresh

# Run + test en un comando
dbt build
```

## Troubleshooting

### "Could not find profile"
```bash
# Verifica que profiles.yml esté en ~/.dbt/
ls ~/.dbt/profiles.yml

# Si no está, créalo como se indica en Paso 3
mkdir -p ~/.dbt
nano ~/.dbt/profiles.yml
```

### "Permission denied"
```bash
# Re-autenticar
gcloud auth application-default login

# Verifica que estás en el proyecto correcto
gcloud config get-value project
```

### "Dataset not found"
```bash
# Crear manualmente
bq mk --dataset YOUR-PROJECT:bank_marketing_dev
bq mk --dataset YOUR-PROJECT:bank_marketing_dev_staging
bq mk --dataset YOUR-PROJECT:bank_marketing_dev_marts
```

### Tests fallan
```bash
# Ver qué registros fallan y por qué
dbt test --store-failures

# Query los fallos
bq query --use_legacy_sql=false \
  'SELECT * FROM `YOUR-PROJECT.bank_marketing_dev.test_*` LIMIT 100'
```

### El modelo tarda mucho
```bash
# BigQuery puede tardar en primera ejecución
# Si tarda >2min, revisa:

# 1. Query cost
bq show --format=prettyjson $(bq ls -j -n 10 | grep CREATE | head -1)

# 2. Slots disponibles
# Free tier tiene límite de slots. Considera upgrade si necesitas más.
```

## Siguientes Pasos

### Conectar a un BI Tool

La tabla `kpi_bank_marketing` está lista para conectar a:
- Looker Studio (gratis)
- Tableau
- Power BI
- Metabase

Solo apunta tu tool a `bank-marketing-demo-001.bank_marketing_dev_marts.kpi_bank_marketing`.

### Modificar los Modelos

Todos los modelos están en `dbt_project/models/`:

```bash
# Editar staging
nano dbt_project/models/staging/staging_bank_marketing.sql

# Editar KPIs
nano dbt_project/models/marts/kpi_bank_marketing.sql

# Ejecutar cambios
dbt run

# Verificar con tests
dbt test
```

### Agregar Tests

En `dbt_project/models/schema.yml`:

```yaml
- name: conversion_rate_pct
  description: Tasa de conversión
  tests:
    - not_null
    - dbt_utils.accepted_range:
        min_value: 0
        max_value: 100
```

O crear test custom en `dbt_project/tests/`:

```sql
-- tests/assert_valid_conversion.sql
SELECT *
FROM {{ ref('kpi_bank_marketing') }}
WHERE conversion_rate_pct > 100
  OR conversion_rate_pct < 0
```

### CI/CD (Opcional)

Si quieres auto-deployment:

1. Hacer fork del repo
2. Crear service account en GCP con permisos de BigQuery
3. Agregar estos secrets en GitHub:
   - `GCP_SERVICE_ACCOUNT_KEY`: JSON key de la service account
   - `DBT_GCP_PROJECT`: ID del proyecto

Los workflows en `.github/workflows/` se ejecutan automáticamente en cada PR y merge.

## Docker (Alternativa)

Si prefieres usar Docker en vez de instalar local:

```bash
# Build
docker-compose build

# Run
docker-compose run dbt-service dbt run

# Test
docker-compose run dbt-service dbt test
```

## Checklist

- [ ] Python venv creado
- [ ] DBT instalado
- [ ] GCP autenticado
- [ ] Dataset creado en BigQuery
- [ ] profiles.yml configurado
- [ ] dbt debug pasa ✓
- [ ] Datos cargados (45,211 registros)
- [ ] dbt deps instalado
- [ ] dbt run exitoso (2 modelos)
- [ ] dbt test exitoso (29 tests)
- [ ] Docs generadas
- [ ] Queries de verificación funcionan

Si todos los checks pasan, estás listo.

## Ayuda

- [README.md](README.md): Overview del proyecto
- [DBT Docs](https://docs.getdbt.com): Documentación oficial
- Logs: `dbt_project/logs/dbt.log`
