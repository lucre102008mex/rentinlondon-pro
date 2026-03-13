# ⚠️ ATENCIÓN: Migración a Supabase Completada

Esta carpeta (`openclaw/services/`) ya **no contiene datos operativos**.

### 🚫 Archivos Deprecados
Los archivos `.json` anteriormente ubicados aquí (leads, bookings, properties, etc.) han sido movidos a `archive_deprecated_v1/`.

### ✅ Única Fuente de Verdad
A partir de ahora, todas las operaciones de lectura y escritura de datos deben realizarse **exclusivamente a través de Supabase**.

- **URL**: https://tiwwthopkvtngpyhchbx.supabase.co
- **Acceso**: Los agentes deben usar la herramienta `supabase_rw` o llamar a los RPCs correspondientes.

No intentes usar archivos locales para persistencia de leads o citas.
