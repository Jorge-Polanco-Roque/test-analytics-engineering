/*
============================================================================
SINGULAR TEST - No Negative Metrics
============================================================================

Propósito:
    Validar que ninguna métrica de conteo o porcentaje sea negativa.

    Métricas validadas:
    - total_contacts
    - successful_contacts
    - unsuccessful_contacts
    - conversion_rate_pct
    - avg_call_duration_min
    - avg_contacts_per_client

Test pasa si:
    No existen registros con valores negativos (query retorna 0 filas)

Test falla si:
    Existen registros con métricas negativas (query retorna filas)


============================================================================
*/

SELECT
    kpi_row_id,
    age_segment,
    job,
    contact_month,

    -- Mostrar métricas problemáticas
    total_contacts,
    successful_contacts,
    unsuccessful_contacts,
    conversion_rate_pct,
    avg_call_duration_min,
    avg_contacts_per_client

FROM {{ ref('kpi_bank_marketing') }}

WHERE
    -- Validar que ninguna métrica sea negativa
    total_contacts < 0
    OR successful_contacts < 0
    OR unsuccessful_contacts < 0
    OR conversion_rate_pct < 0
    OR avg_call_duration_min < 0
    OR avg_contacts_per_client < 0
