# Bank Marketing Analytics

Análisis de efectividad de campañas de marketing telefónico usando DBT y BigQuery.

## El Problema

Una institución bancaria portuguesa realizó campañas de telemarketing entre 2008-2010 para ofrecer depósitos a plazo. De 45,211 contactos realizados, solo ~11.7% resultaron en conversión. Este proyecto transforma esos datos crudos en insights accionables para optimizar futuras campañas.

**Dataset**: [UCI ML Repository - Bank Marketing](https://archive.ics.uci.edu/dataset/222/bank+marketing)

## Arquitectura

```
UCI Dataset → Python → BigQuery Raw → Staging (Views) → Marts (Tables) → Dashboards
```

- **Raw**: 45K registros sin procesar
- **Staging**: Limpieza + 15 features nuevas = 32 columnas
- **Marts**: Agregaciones por dimensiones = 40+ KPIs

## Estructura

```
.
├── data_loading/
│   └── load_to_bigquery.py      # Carga inicial del dataset
├── dbt_project/
│   ├── models/
│   │   ├── staging/
│   │   │   └── staging_bank_marketing.sql    # 4 CTEs de limpieza
│   │   └── marts/
│   │       └── kpi_bank_marketing.sql        # 5 CTEs de agregación
│   ├── tests/                    # 4 tests custom
│   └── macros/                   # 3 macros reutilizables
└── .github/workflows/            # CI/CD automatizado
```

## KPIs Principales

### Conversion Rate
```sql
(contactos_exitosos / total_contactos) × 100
```
Métrica principal. Promedio del dataset: 11.7%

### Efficiency Index
```sql
conversion_rate / promedio_contactos_por_cliente
```
Mide qué tan eficiente es la campaña (menos contactos = mejor)

### Contact Quality Index
```sql
(conversion_rate × duracion_promedio_llamada) / 10
```
Combina conversión con calidad del contacto

## Segmentaciones

El análisis agrupa clientes en múltiples dimensiones:

- **Edad**: 18-25, 26-35, 36-45, 46-55, 56-65, 65+
- **Balance**: negativo, cero, bajo (1-500€), medio (500-2k€), alto (2k-10k€), muy alto (>10k€)
- **Duración**: <1min, 1-3min, 3-5min, 5-10min, >10min
- **Intensidad**: 1 contacto, 2-3, 4-6, 7+ contactos

## Transformaciones

### staging_bank_marketing.sql

4 pasos usando CTEs:

1. **source_data**: Lee la tabla raw
2. **cleaned_data**: Normaliza valores, convierte tipos, maneja nulos
3. **enriched_data**: Crea 15+ features nuevas (segmentos, flags, métricas)
4. **filtered_data**: Elimina registros con edad fuera de rango (18-100) o balance extremo

Output: 32 columnas limpias → View en BigQuery

### kpi_bank_marketing.sql

5 pasos usando CTEs:

1. **base_metrics**: Cuenta contactos por cada combinación de dimensiones
2. **conversion_metrics**: Calcula tasas de conversión
3. **enriched_kpis**: Añade índices, percentiles, rankings
4. **segment_summary**: Promedios por segmento
5. **final_kpi_table**: Combina todo

Output: 47 columnas con KPIs → Tabla particionada en BigQuery

## Tests (29 total)

- **not_null**: En campos críticos (age, subscribed, conversion_rate, etc.)
- **unique**: IDs y combinaciones únicas
- **accepted_values**: Validación de categorías (meses, segmentos)
- **accepted_range**: Rangos válidos (edad 18-100, conversion_rate 0-100)
- **Custom**:
  - `assert_conversion_rate_logic`: Verifica que el cálculo sea correcto
  - `assert_no_negative_metrics`: No métricas negativas en KPIs
  - `assert_total_contacts_sum`: Integridad entre staging y marts
  - `assert_staging_no_duplicates`: Sin duplicados en staging

Todos los tests pasan ✓

## CI/CD

### Pipeline Principal (`.github/workflows/dbt_ci_cd.yml`)

**En Pull Requests:**
- Valida SQL con SQLFluff
- Compila modelos DBT
- Ejecuta en staging
- Corre todos los tests

**En merge a main:**
- Todo lo anterior +
- Deploy a producción
- Genera documentación
- Audita calidad de datos
- Envía notificaciones

### Monitoring (`.github/workflows/data_quality_monitor.yml`)

Corre diariamente a las 7 AM UTC:
- Checa frescura de datos
- Ejecuta los 29 tests
- Crea issue en GitHub si algo falla

## Stack

- **DBT**: 1.7.17 (transformaciones)
- **BigQuery**: Data warehouse
- **Python**: 3.10 (carga de datos)
- **GitHub Actions**: CI/CD
- **SQLFluff**: Linting

## Setup Rápido

```bash
# 1. Clonar
git clone <repo>
cd bank-marketing-dbt

# 2. Instalar
python -m venv venv
source venv/bin/activate
pip install dbt-core==1.7.17 dbt-bigquery==1.7.9

# 3. Configurar GCP
gcloud auth application-default login
gcloud config set project <tu-proyecto>

# 4. Cargar datos
cd data_loading
pip install -r requirements.txt
python load_to_bigquery.py

# 5. Ejecutar DBT
cd ../dbt_project
dbt deps
dbt run
dbt test
```

Ver [HOWTO.md](HOWTO.md) para instrucciones detalladas.

## Comandos

```bash
dbt run                    # Ejecutar modelos
dbt test                   # Ejecutar tests
dbt build                  # run + test
dbt docs generate          # Generar documentación
dbt docs serve             # Ver docs (localhost:8080)
```

## Por Qué Estas Decisiones

**CTEs en vez de subqueries**: Más fácil de leer y debuggear. Puedes comentar CTEs individuales para ver resultados intermedios.

**Views para staging**: Los datos cambian poco y las queries son principalmente para los marts. No tiene sentido duplicar el storage.

**Tables para marts**: Los dashboards pegan aquí constantemente. Mejor tenerlo pre-calculado.

**Muchos tests**: Prefiero que falle el pipeline a tener datos malos en producción. Los tests también sirven como documentación de qué es válido y qué no.

**GitHub Actions**: Gratis, integrado con el repo, fácil de configurar. Para algo más complejo usaría Airflow, pero esto es overkill aquí.

## Cosas Interesantes del Dataset

- Solo 11.7% de conversión (dataset desbalanceado)
- La duración de la llamada es súper predictiva, pero solo la sabes después de la llamada (no sirve para modelos predictivos en tiempo real)
- 82% de clientes nunca habían sido contactados antes
- Mayo es el mejor mes (16% de conversión vs 4% en diciembre)
- Los estudiantes y jubilados convierten mejor que otros grupos

## Referencias

- [Paper original](https://www.sciencedirect.com/science/article/abs/pii/S0167923614000596): Moro, S., Cortez, P., & Rita, P. (2014)
- [Dataset UCI](https://archive.ics.uci.edu/dataset/222/bank+marketing)
- [DBT Docs](https://docs.getdbt.com)
