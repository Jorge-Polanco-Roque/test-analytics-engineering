/*
============================================================================
SINGULAR TEST - Conversion Rate Logic Validation
============================================================================

Propósito:
    Validar que la lógica de cálculo de tasa de conversión es correcta.

    Verifica que:
    conversion_rate_pct = (successful_contacts / total_contacts) * 100

Test pasa si:
    No se encuentran registros con discrepancias (query retorna 0 filas)

Test falla si:
    Existen registros donde el cálculo no coincide (query retorna filas)


============================================================================
*/

-- Seleccionar registros donde el cálculo de conversion_rate_pct es incorrecto
SELECT
    kpi_row_id,
    age_segment,
    job,
    total_contacts,
    successful_contacts,
    conversion_rate_pct,

    -- Recalcular conversion rate
    ROUND(
        SAFE_DIVIDE(successful_contacts, total_contacts) * 100,
        2
    ) AS expected_conversion_rate,

    -- Diferencia
    ABS(
        conversion_rate_pct -
        ROUND(SAFE_DIVIDE(successful_contacts, total_contacts) * 100, 2)
    ) AS difference

FROM {{ ref('kpi_bank_marketing') }}

WHERE
    -- Permitir diferencia máxima de 0.01 por redondeo
    ABS(
        conversion_rate_pct -
        ROUND(SAFE_DIVIDE(successful_contacts, total_contacts) * 100, 2)
    ) > 0.01
