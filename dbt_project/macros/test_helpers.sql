/*test_helpers.sqlMacros útiles para testing y debugging.*/
*/

--
-- log_test_result
--
-- Registra resultados de tests en el log
-- Uso: {{ log_test_result('test_name', passed, message) }}
--
{% macro log_test_result(test_name, passed, message='') %}
    {% if passed %}
        {{ log("✓ TEST PASSED: " ~ test_name ~ " - " ~ message, info=True) }}
    {% else %}
        {{ log("✗ TEST FAILED: " ~ test_name ~ " - " ~ message, info=True) }}
    {% endif %}
{% endmacro %}


--
-- cents_to_euros
--
-- Convierte centavos a euros (útil si los datos vienen en centavos)
-- Uso: {{ cents_to_euros('amount_cents') }} AS amount_eur
--
{% macro cents_to_euros(column_name) %}
    ROUND({{ column_name }} / 100.0, 2)
{% endmacro %}


--
-- get_column_values_as_list
--
-- Obtiene valores únicos de una columna como lista de Python
-- Útil para generar tests dinámicos
-- Uso: {% set values = get_column_values_as_list(ref('model'), 'column') %}
--
{% macro get_column_values_as_list(model, column_name) %}
    {% set query %}
        SELECT DISTINCT {{ column_name }}
        FROM {{ model }}
        WHERE {{ column_name }} IS NOT NULL
        ORDER BY {{ column_name }}
    {% endset %}

    {% set results = run_query(query) %}

    {% if execute %}
        {% set values = results.columns[0].values() %}
        {{ return(values) }}
    {% else %}
        {{ return([]) }}
    {% endif %}
{% endmacro %}


--
-- generate_surrogate_key
--
-- Genera una surrogate key a partir de múltiples columnas
-- Usa MD5 hash de la concatenación
-- Uso: {{ generate_surrogate_key(['col1', 'col2', 'col3']) }} AS sk
--
{% macro generate_surrogate_key(column_list) %}
    TO_HEX(
        MD5(
            CONCAT(
                {% for column in column_list %}
                    COALESCE(CAST({{ column }} AS STRING), '_null_')
                    {% if not loop.last %}, '|', {% endif %}
                {% endfor %}
            )
        )
    )
{% endmacro %}


--
-- log_execution_time
--
-- Registra tiempo de ejecución de un modelo
-- Se ejecuta automáticamente usando post-hook
--
{% macro log_execution_time() %}
    {% if execute %}
        {% set execution_time = (modules.datetime.datetime.now() - run_started_at).total_seconds() %}
        {{ log("⏱️  Execution time: " ~ execution_time ~ " seconds", info=True) }}
    {% endif %}
{% endmacro %}


--
-- get_table_row_count
--
-- Obtiene el número de filas de una tabla
-- Útil para auditoría y validación
-- Uso: {% set count = get_table_row_count(ref('model')) %}
--
{% macro get_table_row_count(relation) %}
    {% set query %}
        SELECT COUNT(*) AS row_count
        FROM {{ relation }}
    {% endset %}

    {% set results = run_query(query) %}

    {% if execute %}
        {% set count = results.columns[0].values()[0] %}
        {{ return(count) }}
    {% else %}
        {{ return(0) }}
    {% endif %}
{% endmacro %}
