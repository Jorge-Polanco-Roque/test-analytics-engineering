# Instrucciones Completas - Docker + DBT

Guía paso a paso para ejecutar el proyecto Bank Marketing Analytics usando Docker.

---

## 📋 Prerequisitos

Antes de empezar, asegúrate de tener:

- ✅ Docker Desktop instalado y corriendo
- ✅ Google Cloud SDK instalado (`gcloud`)
- ✅ Autenticación configurada con GCP
- ✅ Proyecto de BigQuery creado

---

## 🚀 Parte 1: Configuración Inicial (una sola vez)

### Paso 1.1: Verificar Docker

```bash
# Verificar que Docker está corriendo
docker --version
docker ps
```

**Resultado esperado**: Debe mostrar la versión de Docker y contenedores corriendo.

---

### Paso 1.2: Configurar GCP

```bash
# Autenticar con Google Cloud
gcloud auth login

# Configurar credenciales para aplicaciones
gcloud auth application-default login

# Verificar proyecto activo
gcloud config get-value project

# Si necesitas cambiar de proyecto:
gcloud config set project TU_PROYECTO_ID
```

---

### Paso 1.3: Crear profiles.yml de DBT

```bash
# Crear directorio para configuración de DBT
mkdir -p ~/.dbt

# Crear archivo de configuración (REEMPLAZA TU_PROYECTO_ID)
cat > ~/.dbt/profiles.yml << 'EOF'
bank_marketing:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: bank-marketing-analytics-001
      dataset: bank_marketing_dev
      location: US
      threads: 4
      timeout_seconds: 300
      priority: interactive
EOF

# Verificar que se creó correctamente
cat ~/.dbt/profiles.yml
```

**⚠️ IMPORTANTE**: Reemplaza `bank-marketing-analytics-001` con tu PROJECT_ID real.

---

### Paso 1.4: Ir al Directorio del Proyecto

```bash
cd /Users/A1064331/Desktop/Jorge/Otros/DeAcero/bank-marketing-dbt
pwd
```

---

## 🐳 Parte 2: Construir y Levantar Docker

### Paso 2.1: Detener Contenedores Viejos (si existen)

```bash
# Ver contenedores corriendo
docker ps

# Si hay un contenedor viejo, detenerlo
docker stop <CONTAINER_ID>
docker rm <CONTAINER_ID>

# O detener todos los contenedores del proyecto
docker-compose down
```

---

### Paso 2.2: Construir Imagen Docker

```bash
# Construir la imagen (toma 2-3 minutos la primera vez)
docker-compose build

# Verificar que la imagen se creó
docker images | grep bank-marketing
```

**Resultado esperado**: Debe mostrar una imagen `bank-marketing-dbt-dbt`

---

### Paso 2.3: Entrar al Contenedor

```bash
# Levantar contenedor en modo interactivo
docker-compose run --rm dbt bash
```

**Resultado esperado**: Deberías ver un prompt como:
```
root@xxxxxxxxxx:/app#
```

**🎉 ¡Ya estás dentro del contenedor!** Todos los siguientes comandos se ejecutan DENTRO del contenedor.

---

## 🔧 Parte 3: Comandos Dentro del Contenedor

A partir de aquí, todos los comandos son DENTRO del contenedor Docker.

---

### Paso 3.1: Verificar Instalación

```bash
# Verificar versión de Python
python --version
# Esperado: Python 3.10.x

# Verificar versión de DBT
dbt --version
# Esperado: Core 1.7.17, bigquery 1.7.9

# Verificar que estamos en /app
pwd
# Esperado: /app

# Ver estructura del proyecto
ls -la
# Debe mostrar: data_loading/, dbt_project/, docker-compose.yml, etc.
```

---

### Paso 3.2: Verificar Conexión a BigQuery

```bash
# Ir al directorio de DBT
cd /app/dbt_project

# Probar conexión
dbt debug
```

**✅ Resultado esperado**: Al final debe decir `All checks passed!`

**Si falla**, verifica:
- Que ejecutaste `gcloud auth application-default login` en tu Mac
- Que `~/.dbt/profiles.yml` tenga el PROJECT_ID correcto
- Que el dataset existe en BigQuery

---

### Paso 3.3: Cargar Datos a BigQuery

```bash
# Ir al directorio de carga de datos
cd /app/data_loading

# Ejecutar script de carga (REEMPLAZA con tu PROJECT_ID)
python load_to_bigquery.py --project-id bank-marketing-analytics-001 --dataset bank_marketing_dev
```

**✅ Resultado esperado**:
```
✓ Dataset descargado exitosamente: 45,211 registros, 17 columnas
✓ Carga exitosa: 45,211 registros en bank-marketing-analytics-001.bank_marketing_dev.raw_bank_marketing
```

**Tiempo**: ~30 segundos

---

### Paso 3.4: Instalar Paquetes DBT

```bash
# Volver al directorio de DBT
cd /app/dbt_project

# Instalar paquetes (dbt-utils, dbt-expectations, etc.)
dbt deps
```

**✅ Resultado esperado**:
```
Installing dbt-labs/dbt_utils
Installed from version 1.1.1
Installing metaplane/dbt_expectations
Installed from version 0.10.1
Installing dbt-labs/dbt_project_evaluator
Installed from version 0.6.2
```

**Tiempo**: ~5-10 segundos

---

### Paso 3.5: Ejecutar Modelos DBT

```bash
# Ejecutar todos los modelos
dbt run
```

**✅ Resultado esperado**:
```
1 of 40 OK created sql view model bank_marketing_dev_staging.staging_bank_marketing
...
11 of 40 OK created sql table model bank_marketing_dev_marts.kpi_bank_marketing [CREATE TABLE (34.6k rows)]
...
Done. PASS=40 WARN=0 ERROR=0 SKIP=0 TOTAL=40
```

**Qué hace esto**:
- Crea view `staging_bank_marketing` con 45,211 registros limpios
- Crea tabla `kpi_bank_marketing` con ~34,600 registros de KPIs
- Crea 38 tablas adicionales del `dbt_project_evaluator` (auditoría de calidad)

**Tiempo**: ~30 segundos

---

### Paso 3.6: Ejecutar Tests de Calidad

```bash
# Ejecutar todos los tests
dbt test
```

**✅ Resultado esperado**:
```
Done. PASS=45 WARN=4 ERROR=0 SKIP=0 TOTAL=49
```

**Qué valida**:
- No hay valores nulos en campos críticos
- Edades están en rango válido (18-100)
- IDs son únicos
- Conversion rates están entre 0-100%
- Integridad de datos entre staging y marts
- 4 tests custom de lógica de negocio

**Tiempo**: ~15 segundos

---

### Paso 3.7: Ver SQL Compilado (opcional)

```bash
# Compilar sin ejecutar
dbt compile --profiles-dir ~/.dbt

# Ver el SQL generado para staging
cat target/compiled/bank_marketing_analytics/models/staging/staging_bank_marketing.sql | head -100

# Ver el SQL generado para KPIs
cat target/compiled/bank_marketing_analytics/models/marts/kpi_bank_marketing.sql | head -100
```

**Qué hace esto**: Muestra el SQL final que DBT genera a partir de tus modelos con Jinja.

---

### Paso 3.8: Generar Documentación

```bash
# Generar documentación
dbt docs generate
```

**✅ Resultado esperado**:
```
Building catalog
Catalog written to target/catalog.json
```

**Nota**: Para VER la documentación necesitas salir del contenedor y ejecutar `dbt docs serve` desde tu Mac.

---

## 📊 Parte 4: Hacer Queries desde el Contenedor

Para poder hacer queries de BigQuery desde el contenedor, necesitas instalar `bq` CLI:

### Paso 4.1: Instalar Google Cloud SDK

```bash
# Actualizar repositorios
apt-get update

# Instalar google-cloud-sdk (incluye bq)
apt-get install -y google-cloud-sdk
```

**Tiempo**: 1-2 minutos

---

### Paso 4.2: Hacer Queries con bq

```bash
# Query 1: Contar registros raw
bq query --use_legacy_sql=false "SELECT COUNT(*) as total FROM \`bank-marketing-analytics-001.bank_marketing_dev.raw_bank_marketing\`"

# Query 2: Contar registros en staging
bq query --use_legacy_sql=false "SELECT COUNT(*) as total FROM \`bank-marketing-analytics-001.bank_marketing_dev_staging.staging_bank_marketing\`"

# Query 3: Ver conversion rate promedio
bq query --use_legacy_sql=false "SELECT ROUND(AVG(conversion_rate_pct), 2) as avg_conversion FROM \`bank-marketing-analytics-001.bank_marketing_dev_marts.kpi_bank_marketing\`"

# Query 4: Top 5 segmentos de edad
bq query --use_legacy_sql=false "SELECT age_segment, ROUND(AVG(conversion_rate_pct), 2) as conversion, SUM(total_contacts) as contacts FROM \`bank-marketing-analytics-001.bank_marketing_dev_marts.kpi_bank_marketing\` GROUP BY age_segment ORDER BY conversion DESC LIMIT 5"
```

**⚠️ Importante**: Reemplaza `bank-marketing-analytics-001` con tu PROJECT_ID.

---

## 🚪 Parte 5: Salir y Limpiar

### Paso 5.1: Salir del Contenedor

```bash
# Salir del contenedor
exit
```

Esto te devuelve a tu terminal de Mac.

---

### Paso 5.2: Ver Logs (desde tu Mac)

```bash
# Ver logs del contenedor
docker-compose logs

# Ver logs de DBT
cat dbt_project/logs/dbt.log | tail -50
```

---

### Paso 5.3: Limpiar Contenedores (opcional)

```bash
# Detener contenedores
docker-compose down

# Limpiar contenedores parados
docker container prune

# Limpiar imágenes no usadas
docker image prune
```

---

## 🔄 Comandos de Uso Frecuente

### Desarrollo Normal

```bash
# 1. Entrar al contenedor
docker-compose run --rm dbt bash

# 2. Dentro del contenedor, ir a dbt_project
cd /app/dbt_project

# 3. Ejecutar modelos
dbt run

# 4. Ejecutar tests
dbt test

# 5. Salir
exit
```

---

### Ejecutar Modelo Específico

```bash
# Entrar al contenedor
docker-compose run --rm dbt bash

# Solo staging
cd /app/dbt_project
dbt run --select staging_bank_marketing --profiles-dir ~/.dbt

# Solo KPIs
dbt run --select kpi_bank_marketing --profiles-dir ~/.dbt

# Salir
exit
```

---

### Reconstruir desde Cero

```bash
# 1. Detener y eliminar contenedor
docker-compose down
docker system prune -f

# 2. Reconstruir imagen
docker-compose build --no-cache

# 3. Entrar al contenedor
docker-compose run --rm dbt bash

# 4. Dentro del contenedor
cd /app/dbt_project
dbt deps
dbt run --full-refresh --profiles-dir ~/.dbt
dbt test
```

---

## 🐛 Troubleshooting

### Problema: "All checks passed" no aparece en dbt debug

**Causa**: profiles.yml mal configurado o sin credenciales de GCP

**Solución**:
```bash
# Desde tu Mac (NO desde el contenedor)
gcloud auth application-default login

# Verificar que el archivo existe
ls ~/.config/gcloud/application_default_credentials.json

# Verificar profiles.yml
cat ~/.dbt/profiles.yml
```

---

### Problema: "Dataset not found"

**Causa**: Dataset no existe en BigQuery

**Solución**:
```bash
# Desde tu Mac
export PROJECT_ID="bank-marketing-analytics-001"
bq mk --dataset --location=US ${PROJECT_ID}:bank_marketing_dev
```

---

### Problema: "Container name already in use"

**Causa**: Contenedor viejo corriendo

**Solución**:
```bash
# Ver contenedores
docker ps

# Detener contenedor específico
docker stop <CONTAINER_ID>
docker rm <CONTAINER_ID>

# O detener todos
docker-compose down
```

---

### Problema: Load data script falla

**Causa**: No tiene los parámetros requeridos

**Solución**:
```bash
# Dentro del contenedor
cd /app/data_loading
python load_to_bigquery.py --project-id TU_PROYECTO_ID --dataset bank_marketing_dev
```

---

### Problema: Tests fallan

**Causa**: Datos no cargados o paquetes no instalados

**Solución**:
```bash
# Dentro del contenedor
cd /app/dbt_project

# Reinstalar paquetes
dbt deps

# Ejecutar modelos primero
dbt run

# Luego tests
dbt test
```

---

## 📝 Resumen de Comandos Rápidos

### Setup Inicial (una vez)
```bash
# En tu Mac
gcloud auth application-default login
mkdir -p ~/.dbt
# Crear profiles.yml (ver Paso 1.3)
cd /Users/A1064331/Desktop/Jorge/Otros/DeAcero/bank-marketing-dbt
docker-compose build
```

### Workflow Normal
```bash
# En tu Mac
docker-compose run --rm dbt bash

# Dentro del contenedor
cd /app/dbt_project
dbt run
dbt test
exit
```

### Full Refresh
```bash
# Dentro del contenedor
cd /app/data_loading
python load_to_bigquery.py --project-id TU_PROYECTO_ID --dataset bank_marketing_dev

cd /app/dbt_project
dbt deps
dbt run --full-refresh --profiles-dir ~/.dbt
dbt test
```

---

## ✅ Checklist de Verificación

Después de ejecutar todo, deberías tener:

- [ ] Contenedor Docker funcionando
- [ ] Python 3.10.x instalado
- [ ] DBT 1.7.17 instalado
- [ ] `dbt debug` pasa con "All checks passed!"
- [ ] 45,211 registros en `raw_bank_marketing`
- [ ] 45,211 registros en `staging_bank_marketing` (view)
- [ ] ~34,600 registros en `kpi_bank_marketing` (tabla)
- [ ] 45 tests pasando (PASS=45)
- [ ] Conversion rate promedio ~13-14%

---

## 🎯 Próximos Pasos

1. **Explorar datos en BigQuery Console**: https://console.cloud.google.com/bigquery
2. **Ver queries de ejemplo**: Revisa `ejemplos_queries.md`
3. **Ver documentación DBT**: Desde tu Mac ejecuta `dbt docs serve`
4. **Conectar a herramienta BI**: Looker Studio, Tableau, Power BI, etc.

---

**¡Todo listo para trabajar con Docker + DBT!** 🚀
