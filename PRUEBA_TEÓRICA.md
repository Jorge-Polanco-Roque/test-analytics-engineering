### Sección 1: Preguntas de Opción Múltiple

1. **¿Cuál es la función principal del archivo dbt_project.yml?**  
   **b)** Configurar la estructura del proyecto dbt, incluyendo rutas de modelos, macros, seeds, variables y hooks.

2. **En dbt, ¿qué significa el término "materialización" (materialization)?**  
   **a)** El proceso de convertir el código SQL de dbt en objetos de base de datos como tablas o vistas.

3. **¿Cuál de las siguientes materializaciones es la más adecuada para un modelo que contiene datos que cambian frecuentemente y necesitas acceder a la versión más actualizada?**  
   **b)** view

4. **¿Qué problema busca resolver la materialización incremental?**  
   **a)** Reducir el tiempo de ejecución de modelos con grandes volúmenes de datos, procesando solo los cambios desde la última ejecución.

5. **¿Para qué se utilizan los packages en dbt?**  
   **a)** Para encapsular y reutilizar la lógica de negocio, macros y modelos comunes, fomentando las mejores prácticas y la modularidad.

6. **¿Cuál de los siguientes comandos se utiliza para ejecutar las pruebas definidas en un proyecto dbt?**  
   **c)** dbt test

7. **¿Cuál es el propósito de los "seeds" en dbt?**  
   **a)** Cargar datos estáticos o de referencia directamente en la base de datos a través de archivos CSV, ideal para datos pequeños y de configuración.

8. **Si tienes una macro llamada generate_uuid() en tu proyecto, ¿cómo la llamarías dentro de un modelo SQL?**  
   **a)** {{ generate_uuid() }}

9. **¿Cuál es la principal ventaja de usar la directiva ref() en lugar de referenciar directamente las tablas en SQL?**  
   **a)** Permite a dbt construir un grafo de dependencias y gestionar el orden de ejecución, además de manejar automáticamente el esquema y las relaciones entre entornos.

10. **¿Cuál de las siguientes afirmaciones sobre las "exposures" es verdadera?**  
   **b)** Las exposures representan una capa de aplicación, dashboard (BI), o notebook que consume los datos transformados por dbt, documentando el uso downstream.

------------------------------------------------------------------------------------

## Sección 2: Preguntas de Respuesta Corta y Ejemplos

1. **Explica la diferencia entre una materialización `view` y una materialización `table`. ¿Cuándo usarías una sobre la otra?**  
   * Una materialización view no guarda los datos, solo ejecuta la consulta cada vez que se usa, ideal para información que cambia seguido.

   * En cambio, table crea una copia física, lo que acelera las consultas pero ocupa más espacio y tarda en actualizarse.
   
   * Usaría view para datos vivos y table para resultados estables o análisis repetitivos.

2. **Describe cómo implementarías un modelo incremental en dbt. Incluye un ejemplo de cómo dbt gestiona las inserciones/actualizaciones con la cláusula `is_incremental()`.**  
   Un modelo incremental permite procesar solo los registros nuevos o modificados desde la última ejecución. Se define en la configuración del modelo con `materialized='incremental'`.

   **Ejemplo:**
    ```sql
   {{ config(materialized='incremental', unique_key='order_id') }}

   SELECT *
   FROM raw.orders
   {% if is_incremental() %}
     WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
   {% endif %}
   ```

   En la primera ejecución dbt crea la tabla completa. 
   
   En las siguientes, solo inserta o actualiza los registros nuevos según la condición en `is_incremental()`.

3. **¿Qué son las "macros" en dbt y cómo pueden mejorar la mantenibilidad y reusabilidad del código en un proyecto dbt? Proporciona un ejemplo de una macro sencilla que podría ser útil en varios modelos.**  
   Las macros son funciones escritas en Jinja (template engine) que permiten reutilizar lógica SQL, reducir duplicación de código y mantener coherencia en el proyecto. Se comportan como plantillas parametrizables que pueden usarse en distintos modelos. 
   
   En pocas palabras, Jinja convierte SQL estático en SQL programable, lo que hace a dbt mucho más flexible y potente.

   **Ejemplo:**
    Ver respuesta de la pregunta anterior.

4. **Imagina que tienes un modelo `stg_orders` y quieres asegurarte de que la columna `order_id` es única y no nula, y que la columna `order_date` siempre tiene una fecha válida (no es una fecha futura). ¿Cómo definirías estas pruebas en tu archivo `schema.yml`?**
    ```yaml
    models:
     - name: stg_orders
       columns:
         - name: order_id
           tests:
             - not_null
             - unique

         - name: order_date
           tests:
             - not_null
             - dbt_utils.expression_is_true:
                 expression: "order_date <= current_date"
    ```

------------------------------------------------------------------------------------

## Sección 3: Jinja en dbt

1. **Explica la diferencia entre los delimitadores `{{ ... }}` y `{% ... %}` en Jinja dentro de dbt. Proporciona un ejemplo donde usarías cada uno.**  
   * `{{ ... }}` evalúa y devuelve un valor dentro del SQL. Se usa para insertar variables, funciones o macros directamente en la consulta.  
   * `{% ... %}` controla la lógica del flujo: permite usar condicionales, bucles o estructuras de control sin devolver nada directamente.

   **Ejemplo:**
    ```sql
   -- Usando {{ ... }} para insertar un valor  
   SELECT * FROM {{ ref('stg_orders') }}

   -- Usando {% ... %} para ejecutar una condición  
   {% if target.name == 'prod' %}
     WHERE order_date >= current_date - interval '30 days'
   {% endif %}
   ```

   En este ejemplo, `{{ ref('stg_orders') }}` inserta el nombre del modelo, mientras que `{% if ... %}` controla si se aplica una condición según el entorno.

2. **Tienes una tabla `stg_events` con una columna `event_type`. Quieres crear una tabla agregada `fct_event_summary` que cuente los eventos por tipo y por día, pero solo para un conjunto específico de `event_type` que podría variar. Usa una variable de proyecto y Jinja para lograr esto de forma dinámica.**

   **Definición de variable:**
   ```yaml
    vars:  
        event_types: ['login', 'purchase', 'logout']
    ```

   **Modelo `fct_event_summary.sql`:**
    ```sql
   {{ config(materialized='table') }}

   SELECT  
     event_type,  
     event_date,  
     COUNT(*) AS total_events  
   FROM {{ ref('stg_events') }}  
   WHERE event_type IN (  
     {% for e in var('event_types') %}  
       '{{ e }}'{% if not loop.last %}, {% endif %}  
     {% endfor %}  
   )  
   GROUP BY 1, 2
   ```

   Este código usa Jinja para generar dinámicamente la lista de tipos de evento según la variable del proyecto.  

   Si en otro entorno cambian los `event_types`, basta con modificar la variable sin alterar el SQL. Esto hace el modelo flexible y reutilizable.

------------------------------------------------------------------------------------

## Sección 4: Pruebas Estadísticas Personalizadas con Macros

1. **Describe el proceso general para crear una prueba personalizada en dbt usando una macro. ¿Qué estructura básica debe tener la macro de prueba y cómo se invocaría en `schema.yml`?**  

   **Definir la macro de prueba:**

   - Se guarda en la carpeta `macros/tests/`.  
   - La macro debe recibir al menos el argumento `model`, que representa la tabla o vista donde se aplicará la prueba.  
   - Debe devolver una consulta SQL que seleccione las filas que no cumplen la condición.  
   - Si la consulta devuelve resultados, la prueba falla.  

   **Estructura básica de una macro de prueba:**
    ```sql
   {% test nombre_de_prueba(model, column_name) %}
   SELECT *
   FROM {{ model }}
   WHERE {{ column_name }} IS NULL
   {% endtest %}
   ```

   **Invocar la prueba en `schema.yml`:**
    ```yaml
   models:
   - name: my_model  
     columns:
     - name: my_column  
       tests:
       - nombre_de_prueba  
    ```

2. **Crea una macro de prueba personalizada en dbt llamada `test_column_values_below_std_dev_threshold` que falle si algún valor en una columna numérica está más de N desviaciones estándar por encima del promedio. Los argumentos de la macro deben ser `model`, `column_name` y `std_dev_threshold` (el valor por defecto será 3).**

   **Macro `macros/tests/test_column_values_below_std_dev_threshold.sql`:**

    ```sql
   {% test test_column_values_below_std_dev_threshold(model, column_name, std_dev_threshold=3) %}

   WITH stats AS (
     SELECT
       AVG({{ column_name }}) AS mean_val,
       STDDEV({{ column_name }}) AS std_val
     FROM {{ model }}
   )
   SELECT
     {{ column_name }}
   FROM {{ model }}, stats
   WHERE {{ column_name }} > mean_val + (std_dev_threshold * std_val)

   {% endtest %}
   ```

   Esta prueba calcula el promedio y la desviación estándar de la columna, y selecciona las filas cuyo valor excede el umbral definido.

   **Invocación en `schema.yml`:**
    ```yaml
   models:
   - name: fct_sales  
     columns:
     - name: revenue  
       tests:
       - test_column_values_below_std_dev_threshold:
           std_dev_threshold: 2.5 
    ```

   En este ejemplo, la prueba fallará si algún valor de `revenue` está más de 2.5 desviaciones estándar por encima del promedio.

------------------------------------------------------------------------------------

## Sección 5: Diseño y Solución de Problemas Avanzados

### 1. Fuentes

```yaml
sources:
  - name: crm
    database: postgres
    schema: public
    tables:
      - name: customers

  - name: sales
    database: snowflake
    schema: raw
    tables:
      - name: orders

  - name: inventory
    database: bigquery
    schema: raw
    tables:
      - name: products
```

### 2. Seeds

**Archivo:** `data/currency_conversion_rates.csv`  
**Propósito:** Contiene las tasas de conversión de moneda por fecha.  
**Materialización:** `seed` (dbt lo carga como una tabla estática). 
**Uso:** Convertir las ventas a USD dentro de los modelos intermedios.

### 3. Flujo de Modelos (Nombres de modelos, materializaciones y breve resumen)

#### **a. Staging Layer (stg_)**

| Modelo | Fuente | Materialización | Descripción |
|--------|---------|----------------|--------------|
| `stg_customers` | `crm.customers` | `view` | Limpia y renombra campos, mantiene `id_cliente`, `nombre`, `segmento_cliente`, `fecha_registro`. |
| `stg_orders` | `sales.orders` | `view` | Estandariza `id_cliente_crm`, `fecha_pedido`, `id_vendedor`, `total_pedido`, `estado`. |
| `stg_products` | `inventory.products` | `view` | Incluye `id_producto`, `categoria`, `precio_unitario`. |
| `stg_currency_rates` | `seed:currency_conversion_rates` | `view` | Permite unir tasas de conversión con `orders`. |
| `stg_employees` | *(futura fuente)* | `view` | Contendrá `id_vendedor` y `nombre_vendedor`. |

#### **b. Intermediate Layer (int_)**

| Modelo | Materialización | Descripción |
|---------|-----------------|--------------|
| `int_orders_usd` | `table` | Une `stg_orders` con `stg_currency_rates` para calcular `total_pedido_usd`. |
| `int_sales_enriched` | `table` | Combina `int_orders_usd` con `stg_customers` y `stg_employees` para agregar `segmento_cliente` y `nombre_vendedor`. |

**Ejemplo simplificado de `int_orders_usd.sql`:**
```sql
{{ config(materialized='table') }}

SELECT
  o.id_pedido,
  o.id_cliente_crm,
  o.id_vendedor,
  o.fecha_pedido,
  o.total_pedido * c.tasa AS total_pedido_usd
FROM {{ ref('stg_orders') }} o
LEFT JOIN {{ ref('stg_currency_rates') }} c
  ON o.fecha_pedido = c.fecha
  AND c.moneda_origen = 'MXN'
  AND c.moneda_destino = 'USD'
```

#### **c. Fact Layer (fct_)**

| Modelo | Materialización | Descripción |
|---------|-----------------|--------------|
| `fct_daily_sales_performance` | `table` | Agrega las ventas diarias por `id_vendedor` y `segmento_cliente`, calculando `total_ventas_usd_dia` y `numero_pedidos_dia`. |

**Ejemplo de `fct_daily_sales_performance.sql`:**
```sql
{{ config(materialized='table') }}

SELECT
  i.fecha_pedido,
  i.id_vendedor,
  i.nombre_vendedor,
  c.segmento_cliente,
  SUM(i.total_pedido_usd) AS total_ventas_usd_dia,
  COUNT(i.id_pedido) AS numero_pedidos_dia
FROM {{ ref('int_sales_enriched') }} i
JOIN {{ ref('stg_customers') }} c
  ON i.id_cliente_crm = c.id_cliente
GROUP BY 1, 2, 3, 4
```

### 4. Exposure

**Definición en `exposures.yml`:**
```yaml
exposures:
  - name: sales_performance_dashboard
    type: dashboard
    description: "Dashboard de rendimiento diario de ventas por vendedor y segmento."
    maturity: high
    owner:
      name: Equipo de BI
      email: correo@empresa.com
    depends_on:
      - ref('fct_daily_sales_performance')
```

### 5. Linaje

```cs
crm.customers  ─┐
                ├── stg_customers ─┐
sales.orders ───┤                  ├── int_sales_enriched ─── fct_daily_sales_performance ─── [Exposure: Sales Performance Dashboard]
inventory.products ── stg_products ┘
seed.currency_conversion_rates ── stg_currency_rates ─── int_orders_usd ┘
stg_employees ───────────────────────────────────────────┘
```

**Descripción:**
- Las fuentes crudas (`CRM`, `Sales`, `Inventory`, `Seed`) se limpian en los modelos de **staging (`stg_`)**.  
- Luego, se transforman y enriquecen en los modelos **intermedios (`int_`)** para incorporar conversiones a USD y atributos de cliente/vendedor.  
- Finalmente, **`fct_daily_sales_performance`** consolida la información lista para el análisis en herramientas de BI.
