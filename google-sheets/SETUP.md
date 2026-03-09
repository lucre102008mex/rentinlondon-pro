# Google Sheets CRM — Setup Guide
## RentInLondon PRO

## Paso 1: Crear la hoja de cálculo

1. Ve a [sheets.google.com](https://sheets.google.com)
2. Crea una nueva hoja de cálculo
3. Nómbrala: **RentInLondon PRO — CRM**
4. Copia el ID de la URL: `https://docs.google.com/spreadsheets/d/`**ESTE_ES_EL_ID**`/edit`
5. Guarda el ID — lo necesitarás en `GOOGLE_SHEETS_ID`

## Paso 2: Crear las 7 pestañas

Crea exactamente estas pestañas (exactamente con estos nombres):

1. **Leads UK**
2. **Leads Internacionales**
3. **Propiedades**
4. **Viewings**
5. **Contratos**
6. **Ads Report**
7. **Weekly Summary**

## Paso 3: Crear cuenta de servicio en Google Cloud

1. Ve a [console.cloud.google.com](https://console.cloud.google.com)
2. Crea o selecciona un proyecto
3. Habilita la **Google Sheets API**:
   - APIs & Services → Enable APIs → buscar "Google Sheets API" → Enable
4. Crea una cuenta de servicio:
   - IAM & Admin → Service Accounts → Create Service Account
   - Nombre: `rentinlondon-sheets-sync`
   - Rol: ninguno en el proyecto (el acceso lo dará la hoja)
5. Crear y descargar la clave:
   - En la cuenta de servicio → Keys → Add Key → JSON
   - Guarda el archivo JSON en lugar seguro (NO en el repositorio)
6. Del archivo JSON, copia:
   - `client_email` → `GOOGLE_SA_EMAIL`
   - `private_key` → `GOOGLE_SA_PRIVATE_KEY`

## Paso 4: Dar acceso a la cuenta de servicio

1. En la hoja de cálculo, haz clic en **Compartir**
2. Agrega el `client_email` de la cuenta de servicio
3. Permisos: **Editor**
4. Desmarca "Notificar a las personas"
5. Haz clic en **Compartir**

## Paso 5: Configurar las variables de entorno

```bash
# En supabase/.env:
GOOGLE_SA_EMAIL=rentinlondon-sheets-sync@TU_PROYECTO.iam.gserviceaccount.com
GOOGLE_SA_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\nMIIEo...\n-----END RSA PRIVATE KEY-----\n"
GOOGLE_SHEETS_ID=1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms
```

```bash
# Configurar en Supabase Edge Functions Secrets:
supabase secrets set GOOGLE_SA_EMAIL="rentinlondon-sheets-sync@TU_PROYECTO.iam.gserviceaccount.com"
supabase secrets set GOOGLE_SA_PRIVATE_KEY="$(cat ruta/al/archivo.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['private_key'])")"
supabase secrets set GOOGLE_SHEETS_ID="TU_SPREADSHEET_ID"
```

## Paso 6: Agregar headers a cada pestaña

Copia los headers del archivo `sheets-template.json` a la fila 1 de cada pestaña.
La Edge Function `sync-to-sheets` sobrescribirá desde A1, por lo que los headers se incluyen en la primera sincronización.

## Paso 7: Probar la sincronización

```bash
# Generar firma HMAC
PAYLOAD='{"table":"leads"}'
SECRET="TU_WEBHOOK_HMAC_SECRET"
SIG=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" -binary | xxd -p -c 256)

# Llamar a la Edge Function
curl -X POST "https://TU_PROJECT.supabase.co/functions/v1/sync-to-sheets" \
  -H "Content-Type: application/json" \
  -H "X-Signature: sha256=$SIG" \
  -d "$PAYLOAD"

# Respuesta esperada:
# {"success":true,"table":"leads","sheet":"Leads UK","rows_synced":N}
```

## Sincronización Automática

La sincronización ocurre automáticamente cada 6 horas según la configuración en `claw.config.json`:
```json
"sync_to_sheets": {
  "schedule": "0 */6 * * * Europe/London",
  "tables": ["leads", "interactions", "properties", "viewings", "contracts", "listings_history", "weekly_summaries"]
}
```

También se puede disparar manualmente para una tabla específica.

## Estructura de las Pestañas

### Leads UK
Datos de `v_leads_activos` con filtro `es_internacional = FALSE`

### Leads Internacionales  
Datos de `v_leads_activos` con filtro `es_internacional = TRUE`

### Propiedades
Datos completos de la tabla `properties`

### Viewings
Datos de la tabla `viewings` con joins a leads y properties

### Contratos
Datos de la tabla `contracts` (sin datos sensibles de R2R)

### Ads Report
Datos de `listings_history` + métricas de ads de `agent_logs`

### Weekly Summary
Datos de `weekly_summaries` con comparativas semanales
