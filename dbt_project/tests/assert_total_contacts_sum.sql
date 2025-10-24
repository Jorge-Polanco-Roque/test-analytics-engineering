/*
============================================================================
SINGULAR TEST - Total Contacts Sum Validation
============================================================================

Propósito:
    Validar que la suma de successful_contacts + unsuccessful_contacts
    siempre sea igual a total_contacts.

    Esta es una validación de integridad referencial crítica.

Test pasa si:
    No existen discrepancias (query retorna 0 filas)

Test falla si:
    Existen registros donde la suma no coincide (query retorna filas)


============================================================================
*/

SELECT
    kpi_row_id,
    age_segment,
    job,
    contact_month,

    -- Métricas
    total_contacts,
    successful_contacts,
    unsuccessful_contacts,

    -- Suma calculada
    successful_contacts + unsuccessful_contacts AS calculated_total,

    -- Diferencia
    total_contacts - (successful_contacts + unsuccessful_contacts) AS difference

FROM {{ ref('kpi_bank_marketing') }}

WHERE
    -- Debe ser exactamente igual (no permitir ninguna diferencia)
    total_contacts != (successful_contacts + unsuccessful_contacts)
