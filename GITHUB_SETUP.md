# 🔐 Configuración de GitHub Secrets para CI/CD

## ⚠️ IMPORTANTE: Configuración Requerida

Tu pipeline de GitHub Actions está fallando porque **faltan los secrets configurados**. Sigue estos pasos para configurarlo correctamente:

---

## 📋 Paso 1: Acceder a GitHub Secrets

1. Ve a tu repositorio: https://github.com/Jorge-Polanco-Roque/test-analytics-engineering
2. Haz clic en **Settings** (Configuración)
3. En el menú lateral izquierdo, busca **Secrets and variables** → **Actions**
4. Haz clic en **New repository secret**

---

## 🔑 Paso 2: Configurar los Secrets Requeridos

### **Secret 1: GCP_SERVICE_ACCOUNT_KEY**

**Nombre del secret:** `GCP_SERVICE_ACCOUNT_KEY`

**Valor:** El contenido del archivo JSON de la service account (ya está copiado en tu portapapeles)

**Pasos:**
1. Haz clic en **New repository secret**
2. Name: `GCP_SERVICE_ACCOUNT_KEY`
3. Secret: Pega el contenido del JSON (ya lo tienes copiado con `pbcopy`)
4. Haz clic en **Add secret**

**⚠️ El JSON debe verse así:**
```json
{
  "type": "service_account",
  "project_id": "bank-marketing-analytics-001",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "github-actions-dbt@bank-marketing-analytics-001.iam.gserviceaccount.com",
  ...
}
```

---

### **Secret 2: DBT_GCP_PROJECT**

**Nombre del secret:** `DBT_GCP_PROJECT`

**Valor:** `bank-marketing-analytics-001`

**Descripción:** ID del proyecto GCP para development/testing

---

### **Secret 3: DBT_GCP_PROJECT_STAGING**

**Nombre del secret:** `DBT_GCP_PROJECT_STAGING`

**Valor:** `bank-marketing-analytics-001`

**Descripción:** ID del proyecto GCP para staging (usando el mismo proyecto)

---

### **Secret 4: DBT_GCP_PROJECT_PROD**

**Nombre del secret:** `DBT_GCP_PROJECT_PROD`

**Valor:** `bank-marketing-analytics-001`

**Descripción:** ID del proyecto GCP para producción (usando el mismo proyecto)

---

## 🎯 Paso 3: Configurar Environment "production"

El workflow usa un environment llamado `production` que necesita ser creado:

1. En tu repositorio, ve a **Settings** → **Environments**
2. Haz clic en **New environment**
3. Name: `production`
4. **NO AGREGUES** "Required reviewers" por ahora (puedes hacerlo después)
5. Haz clic en **Configure environment**
6. Guarda la configuración

---

## ✅ Paso 4: Verificar la Configuración

Una vez configurados todos los secrets, deberías tener:

- ✅ `GCP_SERVICE_ACCOUNT_KEY` (JSON completo)
- ✅ `DBT_GCP_PROJECT` = `bank-marketing-analytics-001`
- ✅ `DBT_GCP_PROJECT_STAGING` = `bank-marketing-analytics-001`
- ✅ `DBT_GCP_PROJECT_PROD` = `bank-marketing-analytics-001`
- ✅ Environment `production` creado

---

## 🚀 Paso 5: Probar el Pipeline

Una vez configurado todo:

```bash
# 1. Commit los cambios pendientes
git add .
git commit -m "Fix: Update CI/CD configuration for GitHub Actions"
git push origin main
```

El push a `main` debería activar el workflow automáticamente.

---

## 🔍 Paso 6: Monitorear la Ejecución

1. Ve a la pestaña **Actions** en tu repositorio
2. Verás el workflow "DBT CI/CD Pipeline" ejecutándose
3. Haz clic en él para ver los logs en tiempo real
4. Si hay errores, revisa los logs de cada step

---

## 🐛 Troubleshooting Común

### Error: "Secret GCP_SERVICE_ACCOUNT_KEY not found"
**Solución:** Verifica que el nombre del secret sea exactamente `GCP_SERVICE_ACCOUNT_KEY` (case-sensitive)

### Error: "Invalid credentials"
**Solución:** El JSON de la service account está mal formateado. Debe ser el JSON completo sin modificaciones.

### Error: "Permission denied in BigQuery"
**Solución:** La service account ya tiene permisos de `bigquery.admin`. Si persiste, espera 1-2 minutos para que se propaguen los permisos.

### Error: "Environment production not found"
**Solución:** Crea el environment `production` siguiendo el Paso 3.

### Error: "Dataset not found"
**Solución:** Los datasets ya existen:
- `bank_marketing_dev` ✅
- `bank_marketing_staging` ✅
- `bank_marketing_prod` ✅
- `bank_marketing_dev_staging` ✅
- `bank_marketing_dev_marts` ✅

---

## 📊 Datasets Disponibles en BigQuery

Ya tienes estos datasets creados:
```
bank_marketing_dev
bank_marketing_dev_marts
bank_marketing_dev_staging
bank_marketing_prod
bank_marketing_staging
dbt_test__audit
marts
staging
```

---

## 🔒 Seguridad: Eliminar la Key Local

Después de configurar el secret en GitHub, **ELIMINA** el archivo local:

```bash
# Desde tu Mac
rm github-actions-key.json

# Verifica que no esté en git
git status
```

**⚠️ NUNCA COMITEES EL ARCHIVO JSON DE CREDENCIALES A GIT**

Ya está en el `.gitignore` pero es mejor eliminarlo por seguridad.

---

## 📝 Resumen de lo Configurado

✅ **Service Account creada:** `github-actions-dbt@bank-marketing-analytics-001.iam.gserviceaccount.com`
✅ **Permisos otorgados:** `roles/bigquery.admin` y `roles/bigquery.jobUser`
✅ **Key generada:** `github-actions-key.json` (copiada al portapapeles)
✅ **Datasets existentes:** dev, staging, prod
✅ **Workflow configurado:** `.github/workflows/dbt_ci_cd.yml`

---

## 🎯 Próximos Pasos

1. **Ahora mismo:** Configura los 4 secrets en GitHub (Paso 1-2)
2. **Luego:** Crea el environment `production` (Paso 3)
3. **Después:** Haz commit y push (Paso 5)
4. **Finalmente:** Monitorea en la pestaña Actions (Paso 6)

---

¿Necesitas ayuda? Revisa los logs específicos en la pestaña **Actions** del repositorio.
