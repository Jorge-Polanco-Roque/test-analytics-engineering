/*calculate_conversion_rate.sqlMacro para calcular conversion rate de forma consistente.Uso:    {{ calculate_conversion_rate("successful", "total", 2) }}Retorna:    ROUND(SAFE_DIVIDE(successful, total) * 100, 2)*/
        SAFE_DIVIDE({{ numerator }}, {{ denominator }}) * 100,
        {{ decimals }}
    )
{% endmacro %}
