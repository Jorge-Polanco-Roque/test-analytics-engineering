
---

# Ejercicio Práctico para Analytics Engineering

Debe realizar un fork de este repositorio para desarrollar y entregar su trabajo.

Si está interesado en aplicar al test, puede enviar un correo a jgarcial@deacero.com.

## Ejercicio DBT

Este ejercicio utiliza datos de una campaña de marketing por correo electrónico disponibles en el [UCI Machine Learning Repository](https://archive.ics.uci.edu/dataset/222/bank+marketing). Los datos contienen información sobre diversas campañas de marketing directo de una institución bancaria.

**Objetivo del Ejercicio:**

El objetivo es evaluar el dominio de la herramienta DBT (Data Build Tool) del candidato, su capacidad para incorporar pruebas unitarias, mantener la calidad de los datos y desplegar modelos de datos en BigQuery. El objetivo de negocio es crear un Data Mart que permita al equipo de marketing analizar la efectividad de sus campañas, enfocándose en KPIs como la tasa de conversión, el número de contactos exitosos y la segmentación de clientes.

### Instrucciones del Ejercicio:

1. **Configuración del Proyecto DBT:**
    - Crea un nuevo proyecto de DBT.
    - Conéctalo a BigQuery. Asegúrate de configurar correctamente las credenciales y el dataset de destino.
    
2. **Obtención de Datos:**
    - Descarga los datos del [Bank Marketing dataset](https://archive.ics.uci.edu/dataset/222/bank+marketing).
    - Carga los datos en una tabla en BigQuery llamada `raw_bank_marketing`.

3. **Modelado:**
    - Crea un modelo `staging_bank_marketing.sql` para transformar los datos iniciales utilizando CTEs (Common Table Expressions). Este modelo debe realizar las siguientes tareas:
        - Limpiar y normalizar los datos.
        - Filtrar registros irrelevantes.
        - Crear nuevas columnas necesarias para el análisis.
        
    - Crea un modelo `kpi_bank_marketing.sql` para agregar los KPIs de marketing utilizando CTEs. Este modelo debe calcular:
        - Tasa de conversión: porcentaje de contactos exitosos sobre el total de contactos.
        - Número de contactos exitosos: total de conversiones logradas.
        - Segmentación de clientes: clasificación de clientes basada en criterios relevantes como edad, ocupación, etc.
       
4. **Pruebas Unitarias:**
    - Agrega pruebas unitarias en el archivo `schema.yml` para asegurar la integridad de los datos. Incluye pruebas para:
        - Validar tipos de datos.
        - Comprobar valores nulos.
        - Verificar rangos y unicidad de campos clave.
    
5. **Despliegue y Calidad:**
    - Configura un pipeline CI/CD para desplegar los modelos DBT usando herramientas como GitHub Actions o GitLab CI. Asegúrate de incluir pasos para:
        - Validación de código.
        - Ejecución de pruebas unitarias.
        - Despliegue en BigQuery.
    - Configura alertas para pruebas fallidas y realiza auditorías periódicas de calidad de datos. Considera el uso de herramientas como dbt tests, Great Expectations, o similares para automatizar estas auditorías.

### Entrega del Ejercicio

- Suba su proyecto a un repositorio de GitHub.
- Asegúrese de que el repositorio incluya:
    - Todo el código fuente del proyecto DBT.
    - Documentación que explique el proceso seguido, las decisiones tomadas y cómo ejecutar el proyecto.
    - Instrucciones claras sobre cómo configurar y ejecutar el pipeline CI/CD.

### Criterios de Evaluación

- **Exactitud y eficacia del modelo:** ¿Los modelos transforman y agregan los datos de manera correcta y eficiente?
- **Calidad del código:** ¿El código es claro, bien documentado y sigue buenas prácticas?
- **Implementación de pruebas unitarias:** ¿Las pruebas unitarias son exhaustivas y cubren los casos relevantes?
- **Despliegue y automatización:** ¿El pipeline CI/CD está correctamente configurado y automatiza el proceso de despliegue y pruebas?

¡Suerte a todos! 

---
