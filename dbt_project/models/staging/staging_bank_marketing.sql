/*staging_bank_marketing.sqlLimpia los datos raw del dataset de marketing bancario.Input: raw_bank_marketing (45K registros)Output: View con 32 columnas limpias4 CTEs:1. source_data - Lee la tabla raw2. cleaned_data - Normaliza y limpia3. enriched_data - Crea features nuevas (segmentos, flags)4. filtered_data - Filtra registros inválidosFiltros aplicados:- Edad entre 18-100 años- Balance entre -10K y 100K EUR- Sin nulos en campos críticos*/
-- CONFIG: Configuración del modelo
-- ============================================================================
{{
    config(
        materialized='view',
        schema='staging',
        tags=['staging', 'daily', 'bank_marketing']
    )
}}

-- ============================================================================
-- CTE 1: SOURCE - Lectura de datos raw
-- ============================================================================
-- Descripción: Selecciona datos raw con columnas renombradas para claridad
-- ============================================================================
WITH source_data AS (
    SELECT
        -- Identificadores
        _row_id                     AS row_id,
        _dbt_loaded_at              AS loaded_at,

        -- Datos demográficos del cliente
        age,
        job,
        marital,
        education,
        `default`                   AS has_credit_default,
        balance,
        housing                     AS has_housing_loan,
        loan                        AS has_personal_loan,

        -- Datos del contacto actual
        contact                     AS contact_type,
        day_of_week                 AS contact_day,
        month                       AS contact_month,
        duration                    AS contact_duration_sec,

        -- Datos de campaña
        campaign                    AS num_contacts_campaign,
        pdays                       AS days_since_last_contact,
        previous                    AS num_contacts_previous,
        poutcome                    AS previous_outcome,

        -- Variable target
        y                          AS subscribed

    FROM {{ source('raw_bank_marketing', 'raw_bank_marketing') }}
),

-- ============================================================================
-- CTE 2: DATA_CLEANING - Limpieza de datos
-- ============================================================================
-- Descripción:
--   - Normaliza valores categóricos
--   - Maneja valores nulos con estrategias específicas
--   - Convierte strings a formato consistente
-- ============================================================================
cleaned_data AS (
    SELECT
        -- Identificadores (sin cambios)
        row_id,
        loaded_at,

        -- === LIMPIEZA DE DATOS DEMOGRÁFICOS ===

        -- Age: Validar rango y manejar outliers
        CASE
            WHEN age < {{ var('min_age') }} THEN NULL  -- Menor de 18: inválido
            WHEN age > {{ var('max_age') }} THEN NULL  -- Mayor de 100: probable error
            ELSE age
        END AS age,

        -- Job: Normalizar 'unknown' a NULL, limpiar espacios
        CASE
            WHEN LOWER(TRIM(job)) IN ('unknown', '') THEN NULL
            ELSE LOWER(TRIM(job))
        END AS job,

        -- Marital: Normalizar formato
        CASE
            WHEN LOWER(TRIM(marital)) IN ('unknown', '') THEN NULL
            ELSE LOWER(TRIM(marital))
        END AS marital_status,

        -- Education: Normalizar y ordenar niveles
        CASE
            WHEN LOWER(TRIM(education)) IN ('unknown', '') THEN NULL
            WHEN LOWER(TRIM(education)) = 'primary' THEN 'primary'
            WHEN LOWER(TRIM(education)) = 'secondary' THEN 'secondary'
            WHEN LOWER(TRIM(education)) = 'tertiary' THEN 'tertiary'
            ELSE NULL
        END AS education_level,

        -- Credit Default: Convertir a boolean
        CASE
            WHEN LOWER(TRIM(has_credit_default)) = 'yes' THEN TRUE
            WHEN LOWER(TRIM(has_credit_default)) = 'no' THEN FALSE
            ELSE NULL
        END AS has_credit_default,

        -- Balance: Validar rango razonable
        CASE
            WHEN balance < {{ var('min_balance') }} THEN {{ var('min_balance') }}
            WHEN balance > {{ var('max_balance') }} THEN {{ var('max_balance') }}
            ELSE balance
        END AS account_balance_eur,

        -- Housing Loan: Convertir a boolean
        CASE
            WHEN LOWER(TRIM(has_housing_loan)) = 'yes' THEN TRUE
            WHEN LOWER(TRIM(has_housing_loan)) = 'no' THEN FALSE
            ELSE NULL
        END AS has_housing_loan,

        -- Personal Loan: Convertir a boolean
        CASE
            WHEN LOWER(TRIM(has_personal_loan)) = 'yes' THEN TRUE
            WHEN LOWER(TRIM(has_personal_loan)) = 'no' THEN FALSE
            ELSE NULL
        END AS has_personal_loan,

        -- === LIMPIEZA DE DATOS DE CONTACTO ===

        -- Contact Type: Normalizar, unknown → NULL
        CASE
            WHEN LOWER(TRIM(contact_type)) IN ('unknown', '') THEN NULL
            WHEN LOWER(TRIM(contact_type)) = 'cellular' THEN 'cellular'
            WHEN LOWER(TRIM(contact_type)) = 'telephone' THEN 'telephone'
            ELSE NULL
        END AS contact_type,

        -- Contact Day: Validar rango 1-31
        CASE
            WHEN contact_day BETWEEN 1 AND 31 THEN contact_day
            ELSE NULL
        END AS contact_day,

        -- Contact Month: Normalizar formato
        LOWER(TRIM(contact_month)) AS contact_month,

        -- Duration: Validar positivo
        CASE
            WHEN contact_duration_sec < 0 THEN NULL
            ELSE contact_duration_sec
        END AS contact_duration_sec,

        -- === LIMPIEZA DE DATOS DE CAMPAÑA ===

        -- Campaign: Validar positivo
        CASE
            WHEN num_contacts_campaign < 1 THEN NULL
            ELSE num_contacts_campaign
        END AS num_contacts_campaign,

        -- Pdays: Convertir -1 a NULL (sin contacto previo)
        CASE
            WHEN days_since_last_contact = -1 THEN NULL
            WHEN days_since_last_contact < 0 THEN NULL  -- Otros negativos inválidos
            ELSE days_since_last_contact
        END AS days_since_last_contact,

        -- Previous: Validar no negativo
        CASE
            WHEN num_contacts_previous < 0 THEN NULL
            ELSE num_contacts_previous
        END AS num_contacts_previous,

        -- Previous Outcome: Normalizar
        CASE
            WHEN LOWER(TRIM(previous_outcome)) IN ('unknown', '') THEN NULL
            WHEN LOWER(TRIM(previous_outcome)) = 'success' THEN 'success'
            WHEN LOWER(TRIM(previous_outcome)) = 'failure' THEN 'failure'
            WHEN LOWER(TRIM(previous_outcome)) = 'other' THEN 'other'
            ELSE NULL
        END AS previous_campaign_outcome,

        -- === TARGET VARIABLE ===

        -- Subscribed: Convertir a boolean
        CASE
            WHEN LOWER(TRIM(subscribed)) = 'yes' THEN TRUE
            WHEN LOWER(TRIM(subscribed)) = 'no' THEN FALSE
            ELSE NULL
        END AS subscribed

    FROM source_data
),

-- ============================================================================
-- CTE 3: FEATURE_ENGINEERING - Creación de features derivadas
-- ============================================================================
-- Descripción:
--   - Genera nuevas columnas útiles para análisis
--   - Calcula agregaciones a nivel de fila
--   - Crea flags de segmentación
-- ============================================================================
enriched_data AS (
    SELECT
        *,

        -- === FEATURES DEMOGRÁFICAS ===

        -- Segmentación por edad
        CASE
            WHEN age IS NULL THEN 'unknown'
            WHEN age BETWEEN 18 AND 25 THEN '18-25'
            WHEN age BETWEEN 26 AND 35 THEN '26-35'
            WHEN age BETWEEN 36 AND 45 THEN '36-45'
            WHEN age BETWEEN 46 AND 55 THEN '46-55'
            WHEN age BETWEEN 56 AND 65 THEN '56-65'
            WHEN age > 65 THEN '65+'
            ELSE 'unknown'
        END AS age_segment,

        -- Segmentación por balance
        CASE
            WHEN account_balance_eur IS NULL THEN 'unknown'
            WHEN account_balance_eur < 0 THEN 'negative'
            WHEN account_balance_eur = 0 THEN 'zero'
            WHEN account_balance_eur BETWEEN 1 AND 500 THEN 'low (1-500)'
            WHEN account_balance_eur BETWEEN 501 AND 2000 THEN 'medium (501-2k)'
            WHEN account_balance_eur BETWEEN 2001 AND 10000 THEN 'high (2k-10k)'
            WHEN account_balance_eur > 10000 THEN 'very_high (10k+)'
            ELSE 'unknown'
        END AS balance_segment,

        -- Flag: Cliente con deudas (default o balance negativo)
        CASE
            WHEN has_credit_default = TRUE OR account_balance_eur < 0 THEN TRUE
            ELSE FALSE
        END AS has_debt_indicators,

        -- Flag: Cliente con algún préstamo activo
        CASE
            WHEN has_housing_loan = TRUE OR has_personal_loan = TRUE THEN TRUE
            ELSE FALSE
        END AS has_any_loan,

        -- === FEATURES DE CONTACTO ===

        -- Duración del contacto en minutos (más intuitivo)
        ROUND(contact_duration_sec / 60.0, 2) AS contact_duration_min,

        -- Segmentación por duración de llamada
        CASE
            WHEN contact_duration_sec IS NULL THEN 'unknown'
            WHEN contact_duration_sec = 0 THEN 'no_contact'
            WHEN contact_duration_sec < 60 THEN 'very_short (<1min)'
            WHEN contact_duration_sec BETWEEN 60 AND 180 THEN 'short (1-3min)'
            WHEN contact_duration_sec BETWEEN 181 AND 300 THEN 'medium (3-5min)'
            WHEN contact_duration_sec BETWEEN 301 AND 600 THEN 'long (5-10min)'
            WHEN contact_duration_sec > 600 THEN 'very_long (10min+)'
            ELSE 'unknown'
        END AS call_duration_segment,

        -- Convertir mes a número para ordenamiento
        CASE contact_month
            WHEN 'jan' THEN 1
            WHEN 'feb' THEN 2
            WHEN 'mar' THEN 3
            WHEN 'apr' THEN 4
            WHEN 'may' THEN 5
            WHEN 'jun' THEN 6
            WHEN 'jul' THEN 7
            WHEN 'aug' THEN 8
            WHEN 'sep' THEN 9
            WHEN 'oct' THEN 10
            WHEN 'nov' THEN 11
            WHEN 'dec' THEN 12
            ELSE NULL
        END AS contact_month_num,

        -- Trimestre del contacto
        CASE
            WHEN contact_month IN ('jan', 'feb', 'mar') THEN 'Q1'
            WHEN contact_month IN ('apr', 'may', 'jun') THEN 'Q2'
            WHEN contact_month IN ('jul', 'aug', 'sep') THEN 'Q3'
            WHEN contact_month IN ('oct', 'nov', 'dec') THEN 'Q4'
            ELSE NULL
        END AS contact_quarter,

        -- === FEATURES DE CAMPAÑA ===

        -- Flag: Cliente contactado previamente
        CASE
            WHEN num_contacts_previous > 0 THEN TRUE
            ELSE FALSE
        END AS was_contacted_before,

        -- Flag: Cliente con contacto reciente (< 30 días)
        CASE
            WHEN days_since_last_contact IS NOT NULL
                AND days_since_last_contact < 30 THEN TRUE
            ELSE FALSE
        END AS recently_contacted,

        -- Segmentación por intensidad de campaña
        CASE
            WHEN num_contacts_campaign IS NULL THEN 'unknown'
            WHEN num_contacts_campaign = 1 THEN 'single_contact'
            WHEN num_contacts_campaign BETWEEN 2 AND 3 THEN 'low (2-3)'
            WHEN num_contacts_campaign BETWEEN 4 AND 6 THEN 'medium (4-6)'
            WHEN num_contacts_campaign > 6 THEN 'high (7+)'
            ELSE 'unknown'
        END AS campaign_intensity,

        -- Flag: Éxito en campaña anterior
        CASE
            WHEN previous_campaign_outcome = 'success' THEN TRUE
            ELSE FALSE
        END AS previous_campaign_success

    FROM cleaned_data
),

-- ============================================================================
-- CTE 4: FINAL_FILTERING - Filtrado de registros inválidos
-- ============================================================================
-- Descripción:
--   - Elimina registros que no cumplen requisitos mínimos de calidad
--   - Registros con NULL en campos críticos son excluidos
-- ============================================================================
filtered_data AS (
    SELECT
        *
    FROM enriched_data
    WHERE
        -- Requisito: Target debe estar presente (crítico para análisis)
        subscribed IS NOT NULL

        -- Requisito: Edad válida (campo clave para segmentación)
        AND age IS NOT NULL

        -- Requisito: Al menos un contacto en la campaña
        AND num_contacts_campaign >= 1

        -- Requisito: Datos básicos de contacto
        AND contact_month IS NOT NULL
)

-- ============================================================================
-- FINAL SELECT: Ordenamiento y selección de columnas
-- ============================================================================
SELECT
    -- === IDENTIFICADORES ===
    row_id,
    loaded_at,

    -- === DATOS DEMOGRÁFICOS (LIMPIOS) ===
    age,
    age_segment,
    job,
    marital_status,
    education_level,
    has_credit_default,
    account_balance_eur,
    balance_segment,
    has_housing_loan,
    has_personal_loan,
    has_any_loan,
    has_debt_indicators,

    -- === DATOS DE CONTACTO (LIMPIOS) ===
    contact_type,
    contact_day,
    contact_month,
    contact_month_num,
    contact_quarter,
    contact_duration_sec,
    contact_duration_min,
    call_duration_segment,

    -- === DATOS DE CAMPAÑA (LIMPIOS) ===
    num_contacts_campaign,
    campaign_intensity,
    days_since_last_contact,
    recently_contacted,
    num_contacts_previous,
    was_contacted_before,
    previous_campaign_outcome,
    previous_campaign_success,

    -- === TARGET ===
    subscribed,

    -- === METADATA ===
    CURRENT_TIMESTAMP() AS dbt_updated_at

FROM filtered_data

-- Ordenar por mes y día para mantener cronología
ORDER BY contact_month_num, contact_day
