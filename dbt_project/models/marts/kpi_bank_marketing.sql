/*kpi_bank_marketing.sqlCalcula KPIs de las campañas de marketing agregando por múltiples dimensiones.Input: staging_bank_marketing (45K registros)Output: Tabla particionada con 35K registros de KPIs (47 columnas)5 CTEs:1. base_metrics - Cuenta contactos por dimensión2. conversion_metrics - Calcula tasas de conversión3. enriched_kpis - Añade índices (efficiency, quality, percentiles)4. segment_summary - Promedios por segmento5. final_kpi_table - Combina todoKPIs principales:- Conversion Rate: (exitosos / total) × 100- Efficiency Index: conversión / promedio_contactos- Contact Quality Index: (conversión × duración) / 10*/

-- ============================================================================
-- CONFIG: Configuración del modelo
-- ============================================================================
{{
    config(
        materialized='table',
        schema='marts',
        tags=['marts', 'kpi', 'daily', 'bank_marketing'],
        partition_by={
            'field': 'contact_month_num',
            'data_type': 'int64',
            'range': {
                'start': 1,
                'end': 13,
                'interval': 1
            }
        }
    )
}}

-- ============================================================================
-- CTE 1: BASE_METRICS - Métricas base por dimensión
-- ============================================================================
WITH base_metrics AS (
    SELECT
        -- === DIMENSIONES DE AGRUPACIÓN ===
        age_segment,
        job,
        marital_status,
        education_level,
        balance_segment,
        contact_type,
        contact_month,
        contact_month_num,
        contact_quarter,
        call_duration_segment,
        campaign_intensity,
        previous_campaign_outcome,
        has_any_loan,
        has_debt_indicators,
        was_contacted_before,

        -- === MÉTRICAS BÁSICAS ===

        -- Total de contactos
        COUNT(*) AS total_contacts,

        -- Contactos exitosos (suscripciones)
        SUM(CASE WHEN subscribed = TRUE THEN 1 ELSE 0 END) AS successful_contacts,

        -- Contactos no exitosos
        SUM(CASE WHEN subscribed = FALSE THEN 1 ELSE 0 END) AS unsuccessful_contacts,

        -- === MÉTRICAS DE DURACIÓN ===

        -- Duración promedio de llamada (segundos)
        AVG(contact_duration_sec) AS avg_call_duration_sec,

        -- Duración promedio de llamada (minutos)
        AVG(contact_duration_min) AS avg_call_duration_min,

        -- Duración mediana
        APPROX_QUANTILES(contact_duration_sec, 100)[OFFSET(50)] AS median_call_duration_sec,

        -- Duración total de todas las llamadas
        SUM(contact_duration_sec) AS total_call_duration_sec,

        -- === MÉTRICAS DE CAMPAÑA ===

        -- Promedio de contactos por cliente en campaña
        AVG(num_contacts_campaign) AS avg_contacts_per_client,

        -- Máximo de contactos a un cliente
        MAX(num_contacts_campaign) AS max_contacts_to_client,

        -- === MÉTRICAS DEMOGRÁFICAS ===

        -- Edad promedio
        AVG(age) AS avg_age,

        -- Balance promedio de cuenta
        AVG(account_balance_eur) AS avg_account_balance,

        -- Balance mediano
        APPROX_QUANTILES(account_balance_eur, 100)[OFFSET(50)] AS median_account_balance,

        -- === MÉTRICAS DE CONTACTOS PREVIOS ===

        -- Porcentaje de clientes contactados antes
        AVG(CASE WHEN was_contacted_before THEN 1.0 ELSE 0.0 END) AS pct_previously_contacted,

        -- Promedio días desde último contacto (solo para quienes fueron contactados)
        AVG(days_since_last_contact) AS avg_days_since_last_contact

    FROM {{ ref('staging_bank_marketing') }}

    GROUP BY
        age_segment,
        job,
        marital_status,
        education_level,
        balance_segment,
        contact_type,
        contact_month,
        contact_month_num,
        contact_quarter,
        call_duration_segment,
        campaign_intensity,
        previous_campaign_outcome,
        has_any_loan,
        has_debt_indicators,
        was_contacted_before
),

-- ============================================================================
-- CTE 2: CONVERSION_METRICS - Métricas de conversión
-- ============================================================================
conversion_metrics AS (
    SELECT
        *,

        -- === TASA DE CONVERSIÓN ===
        -- Métrica principal: porcentaje de contactos que resultaron en suscripción
        ROUND(
            SAFE_DIVIDE(successful_contacts, total_contacts) * 100,
            2
        ) AS conversion_rate_pct,

        -- === TASA DE NO CONVERSIÓN ===
        ROUND(
            SAFE_DIVIDE(unsuccessful_contacts, total_contacts) * 100,
            2
        ) AS non_conversion_rate_pct,

        -- === EFICIENCIA DE LLAMADA ===
        -- Conversión por minuto de llamada
        ROUND(
            SAFE_DIVIDE(successful_contacts, total_call_duration_sec / 60.0),
            4
        ) AS conversions_per_call_minute,

        -- === BENCHMARK VS OBJETIVO ===
        -- Comparación con el umbral de conversión objetivo (definido en vars)
        CASE
            WHEN SAFE_DIVIDE(successful_contacts, total_contacts) >= {{ var('success_threshold') }}
                THEN 'above_target'
            WHEN SAFE_DIVIDE(successful_contacts, total_contacts) >= {{ var('success_threshold') }} * 0.8
                THEN 'near_target'
            ELSE 'below_target'
        END AS performance_vs_target,

        -- === SEGMENTACIÓN DE PERFORMANCE ===
        CASE
            WHEN SAFE_DIVIDE(successful_contacts, total_contacts) >= 0.20 THEN 'high_performance'
            WHEN SAFE_DIVIDE(successful_contacts, total_contacts) >= 0.10 THEN 'medium_performance'
            WHEN SAFE_DIVIDE(successful_contacts, total_contacts) >= 0.05 THEN 'low_performance'
            ELSE 'very_low_performance'
        END AS performance_segment

    FROM base_metrics
),

-- ============================================================================
-- CTE 3: ENRICHED_KPIs - KPIs enriquecidos con contexto
-- ============================================================================
enriched_kpis AS (
    SELECT
        *,

        -- === ÍNDICES CALCULADOS ===

        -- Índice de eficiencia (conversión ajustada por esfuerzo)
        -- Formula: (conversion_rate / avg_contacts_per_client) * 100
        ROUND(
            SAFE_DIVIDE(
                conversion_rate_pct,
                avg_contacts_per_client
            ),
            2
        ) AS efficiency_index,

        -- Índice de calidad de contacto
        -- Formula: (conversion_rate * avg_call_duration_min) / 10
        -- Pondera conversión con duración de llamada
        ROUND(
            (conversion_rate_pct * avg_call_duration_min) / 10,
            2
        ) AS contact_quality_index,

        -- === RANKINGS ===

        -- Rank de conversión dentro de cada segmento de edad
        ROW_NUMBER() OVER (
            PARTITION BY age_segment
            ORDER BY conversion_rate_pct DESC
        ) AS conversion_rank_by_age,

        -- Rank de conversión dentro de cada mes
        ROW_NUMBER() OVER (
            PARTITION BY contact_month
            ORDER BY conversion_rate_pct DESC
        ) AS conversion_rank_by_month,

        -- === PERCENTILES ===

        -- Percentil de tasa de conversión (0-100)
        PERCENT_RANK() OVER (
            ORDER BY conversion_rate_pct
        ) AS conversion_percentile

    FROM conversion_metrics
),

-- ============================================================================
-- CTE 4: SEGMENT_SUMMARY - Resumen por segmento principal
-- ============================================================================
segment_summary AS (
    SELECT
        age_segment,
        job,
        education_level,
        balance_segment,

        -- Agregaciones de segundo nivel
        SUM(total_contacts) AS total_contacts_in_segment,
        SUM(successful_contacts) AS total_conversions_in_segment,
        AVG(conversion_rate_pct) AS avg_conversion_rate_in_segment,

        -- Mejor mes para este segmento
        MAX(
            CASE
                WHEN conversion_rank_by_month = 1
                THEN contact_month
                ELSE NULL
            END
        ) AS best_month_for_segment

    FROM enriched_kpis

    GROUP BY
        age_segment,
        job,
        education_level,
        balance_segment
),

-- ============================================================================
-- CTE 5: FINAL_KPI_TABLE - Tabla final con todas las métricas
-- ============================================================================
final_kpi_table AS (
    SELECT
        e.*,

        -- Agregar resumen del segmento
        s.total_contacts_in_segment,
        s.total_conversions_in_segment,
        s.avg_conversion_rate_in_segment,
        s.best_month_for_segment,

        -- === MÉTRICAS DERIVADAS FINALES ===

        -- Share of voice: % de contactos de este grupo vs total del segmento
        ROUND(
            SAFE_DIVIDE(e.total_contacts, s.total_contacts_in_segment) * 100,
            2
        ) AS share_of_contacts_in_segment_pct,

        -- Performance relativa vs promedio del segmento
        ROUND(
            e.conversion_rate_pct - s.avg_conversion_rate_in_segment,
            2
        ) AS conversion_rate_vs_segment_avg,

        -- Flag: ¿Es el mejor grupo en su segmento?
        CASE
            WHEN e.conversion_rank_by_age = 1 THEN TRUE
            ELSE FALSE
        END AS is_top_performer_in_age_segment

    FROM enriched_kpis e
    LEFT JOIN segment_summary s
        ON e.age_segment = s.age_segment
        AND e.job = s.job
        AND e.education_level = s.education_level
        AND e.balance_segment = s.balance_segment
)

-- ============================================================================
-- FINAL SELECT: Selección ordenada de KPIs
-- ============================================================================
SELECT
    -- === IDENTIFICADORES Y DIMENSIONES ===
    ROW_NUMBER() OVER (ORDER BY conversion_rate_pct DESC) AS kpi_row_id,

    -- Dimensiones demográficas
    age_segment,
    job,
    marital_status,
    education_level,
    balance_segment,
    has_any_loan,
    has_debt_indicators,

    -- Dimensiones de contacto
    contact_type,
    contact_month,
    contact_month_num,
    contact_quarter,
    call_duration_segment,

    -- Dimensiones de campaña
    campaign_intensity,
    previous_campaign_outcome,
    was_contacted_before,

    -- === MÉTRICAS BÁSICAS ===
    total_contacts,
    successful_contacts,
    unsuccessful_contacts,

    -- === KPIs PRINCIPALES ===
    conversion_rate_pct,
    non_conversion_rate_pct,
    conversions_per_call_minute,

    -- === MÉTRICAS DE DURACIÓN ===
    avg_call_duration_sec,
    avg_call_duration_min,
    median_call_duration_sec,
    total_call_duration_sec,

    -- === MÉTRICAS DE CAMPAÑA ===
    avg_contacts_per_client,
    max_contacts_to_client,

    -- === MÉTRICAS DEMOGRÁFICAS ===
    avg_age,
    avg_account_balance,
    median_account_balance,

    -- === MÉTRICAS DE HISTORIAL ===
    pct_previously_contacted,
    avg_days_since_last_contact,

    -- === ÍNDICES Y RANKINGS ===
    efficiency_index,
    contact_quality_index,
    conversion_rank_by_age,
    conversion_rank_by_month,
    conversion_percentile,

    -- === PERFORMANCE Y SEGMENTACIÓN ===
    performance_vs_target,
    performance_segment,
    is_top_performer_in_age_segment,

    -- === MÉTRICAS DE SEGMENTO ===
    total_contacts_in_segment,
    total_conversions_in_segment,
    avg_conversion_rate_in_segment,
    best_month_for_segment,
    share_of_contacts_in_segment_pct,
    conversion_rate_vs_segment_avg,

    -- === METADATA ===
    CURRENT_TIMESTAMP() AS dbt_updated_at,
    '{{ run_started_at }}' AS dbt_run_timestamp

FROM final_kpi_table

/*
Note: ORDER BY removed because partitioned tables cannot have ORDER BY in creation query.
Users can add ORDER BY when querying the table.
============================================================================
NOTAS DE USO Y QUERIES EJEMPLO
============================================================================

-- 1. TOP 10 SEGMENTOS CON MEJOR CONVERSIÓN
SELECT
    age_segment,
    job,
    education_level,
    conversion_rate_pct,
    total_contacts,
    successful_contacts
FROM {{ this }}
WHERE total_contacts >= 100  -- Filtrar segmentos con suficiente volumen
ORDER BY conversion_rate_pct DESC
LIMIT 10;

-- 2. TENDENCIA DE CONVERSIÓN POR MES
SELECT
    contact_month,
    SUM(total_contacts) AS total_contacts,
    SUM(successful_contacts) AS total_conversions,
    AVG(conversion_rate_pct) AS avg_conversion_rate
FROM {{ this }}
GROUP BY contact_month, contact_month_num
ORDER BY contact_month_num;

-- 3. SEGMENTOS BAJO PERFORMANCE QUE NECESITAN ATENCIÓN
SELECT
    age_segment,
    job,
    balance_segment,
    conversion_rate_pct,
    total_contacts,
    performance_segment
FROM {{ this }}
WHERE performance_segment = 'very_low_performance'
    AND total_contacts >= 50
ORDER BY total_contacts DESC;

-- 4. ANÁLISIS DE ROI POR DURACIÓN DE LLAMADA
SELECT
    call_duration_segment,
    SUM(total_contacts) AS total_calls,
    SUM(successful_contacts) AS conversions,
    AVG(conversion_rate_pct) AS avg_conversion_rate,
    AVG(avg_call_duration_min) AS avg_duration_min,
    AVG(conversions_per_call_minute) AS conversions_per_min
FROM {{ this }}
GROUP BY call_duration_segment
ORDER BY conversions_per_min DESC;

============================================================================
*/
