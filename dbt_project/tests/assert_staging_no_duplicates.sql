/*
============================================================================
SINGULAR TEST - No Duplicate Row IDs in Staging
============================================================================

Propósito:
    Validar que no existan row_id duplicados en staging.

    El row_id debe ser único ya que representa registros individuales
    de la tabla raw.

Test pasa si:
    No existen duplicados (query retorna 0 filas)

Test falla si:
    Existen row_id con más de 1 ocurrencia (query retorna filas)


============================================================================
*/

SELECT
    row_id,
    COUNT(*) AS occurrences

FROM {{ ref('staging_bank_marketing') }}

GROUP BY row_id

HAVING COUNT(*) > 1

ORDER BY occurrences DESC
