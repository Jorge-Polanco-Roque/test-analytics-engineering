/*
generate_schema_name.sql

Personaliza cómo DBT genera nombres de schemas.

Por defecto DBT hace: <target_schema>_<custom_schema>
Esta macro hace: <custom_schema> (sin prefijo)

Resultado:
- dev: bank_marketing_dev_staging
- prod: staging (limpio)
*/

{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}

    {%- if custom_schema_name is none -%}
        {# Si no hay custom schema, usar el default #}
        {{ default_schema }}

    {%- elif target.name == 'prod' -%}
        {# En producción, usar solo el custom schema (sin prefijo) #}
        {{ custom_schema_name | trim }}

    {%- else -%}
        {# En dev/staging, usar prefijo para separar entornos #}
        {{ default_schema }}_{{ custom_schema_name | trim }}

    {%- endif -%}

{%- endmacro %}
