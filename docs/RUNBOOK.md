# RUNBOOK.md — Guía Operativa Completa
## RentInLondon PRO

## Operaciones Diarias

### 8:00 AM — Inicio del día
Alex envía automáticamente el reporte diario al dueño por Telegram. 

**Si no llega el reporte:**
```bash
# Ejecutar manualmente
openclaw pipelines run daily-report

# Ver logs para diagnóstico
tail -50 /var/log/rentinlondon/agent.log | grep "daily-report"
```

### Durante el día

**Revisar leads HOT sin contacto:**
```
Telegram → /leads hot
```

**Revisar propiedades void:**
```
Telegram → /void
```

**Ver estado de agentes:**
```bash
openclaw status
```

## Gestión de Leads

### Agregar un lead manualmente
```sql
INSERT INTO public.leads (
  nombre, telefono, canal_origen,
  zona_preferida, presupuesto_max, tipo_propiedad,
  fecha_mudanza, asignado_a
) VALUES (
  'Nombre del Prospecto',
  '+447123456789',
  'whatsapp',
  'Shoreditch',
  1500,
  '1bed',
  '2025-04-01',
  'ivy'
);
-- Los triggers calculan automáticamente urgency_score, data_completeness y budget_fit
```

### Reasignar un lead a otro agente
```sql
UPDATE public.leads
SET asignado_a = 'jeanette',
    escalado_jeanette = TRUE,
    escalado_at = NOW(),
    motivo_escalado = 'Reasignación manual — lead internacional detectado'
WHERE id = 'uuid_del_lead';
```

### Marcar lead como perdido
```sql
UPDATE public.leads
SET status = 'perdido',
    pipeline_stage = 'lost',
    notas = 'Motivo: [explicación]'
WHERE id = 'uuid_del_lead';
```

## Gestión de Propiedades

### Agregar una propiedad nueva
```sql
INSERT INTO public.properties (
  direccion, zona, tipo, precio_mensual,
  disponible_desde, descripcion,
  bills_incluidos, deposito_semanas, min_contrato_meses
) VALUES (
  '15 Example Street, E1 6RF',
  'Shoreditch',
  '1bed',
  1800,
  '2025-04-01',
  'Modern 1 bedroom flat in the heart of Shoreditch...',
  FALSE,
  5,
  6
);
-- Inmediatamente disponible para matching con leads
-- ads-gumtree creará el listado en el próximo listings-refresh (lun/jue 11 AM)
```

### Marcar propiedad como alquilada
```sql
UPDATE public.properties
SET estado = 'let'
WHERE id = 'uuid_de_la_propiedad';
-- ads-gumtree pausará automáticamente los listados en el próximo refresh
```

### Cancelar un viewing
```sql
UPDATE public.viewings
SET estado = 'cancelado_agencia',
    notas = 'Motivo: propiedad ya alquilada'
WHERE id = 'uuid_del_viewing';
-- Notificar manualmente al lead por WhatsApp
```

## Gestión de Contratos

### Crear un contrato
Solo Jeanette (o human) debe crear contratos:
```sql
INSERT INTO public.contracts (
  lead_id, property_id, agente_cierre,
  fecha_inicio, fecha_fin,
  precio_mensual, deposito_pagado,
  estado, tipo_contrato,
  r2r_verificado, r2r_verificado_at, r2r_tipo_doc
) VALUES (
  'uuid_lead',
  'uuid_propiedad',
  'jeanette',
  '2025-04-01',
  '2026-03-31',
  1800,
  2160,  -- 6 semanas de depósito
  'firmado',
  'ast',
  TRUE,
  NOW(),
  'british_passport'
);
-- Actualizar estado del lead
UPDATE leads SET status = 'contrato_firmado' WHERE id = 'uuid_lead';
-- Actualizar estado de la propiedad
UPDATE properties SET estado = 'let' WHERE id = 'uuid_propiedad';
```

## Operaciones de Sistema

### Reiniciar el gateway de OpenClaw
```bash
# Con systemd
sudo systemctl restart openclaw

# Sin systemd
cd /home/ubuntu/rentinlondon-pro/openclaw
openclaw stop
openclaw start --config config.yaml
```

### Aplicar nuevas migraciones SQL
```bash
cd /home/ubuntu/rentinlondon-pro
supabase db push
```

### Desplegar Edge Function actualizada
```bash
supabase functions deploy sync-to-sheets
supabase functions deploy webhook-receiver
```

### Regenerar snapshot de contexto para Alex
```bash
bash /home/ubuntu/rentinlondon-pro/setup/context_loader.sh
```

### Ver logs en tiempo real
```bash
# Todos los logs
tail -f /var/log/rentinlondon/agent.log

# Solo errores
tail -f /var/log/rentinlondon/agent.log | grep -i "error\|alert"

# Por agente específico
tail -f /var/log/rentinlondon/agent.log | grep -i "JEANETTE"
```

## Resolución de Problemas Comunes

### ❌ Agente no responde
1. Verificar estado: `openclaw status`
2. Ver logs: `tail -50 /var/log/rentinlondon/agent.log`
3. Reiniciar agente específico: `openclaw restart --agent ivy`
4. Si persiste: reiniciar gateway completo

### ❌ Google Sheets no se actualiza
1. Verificar Edge Function: `supabase functions list`
2. Ver logs de la función: `supabase functions logs sync-to-sheets`
3. Verificar secretos: `supabase secrets list`
4. Probar manualmente:
```bash
PAYLOAD='{"table":"leads"}'
SECRET="$WEBHOOK_HMAC_SECRET"
SIG=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" -binary | xxd -p -c 256)
curl -X POST "$SUPABASE_URL/functions/v1/sync-to-sheets" \
  -H "Content-Type: application/json" \
  -H "X-Signature: sha256=$SIG" \
  -d "$PAYLOAD"
```

### ❌ Pipeline no ejecuta a la hora programada
1. Verificar timezone del servidor: `timedatectl`
2. Verificar pipelines activos: `openclaw pipelines list`
3. Ejecutar manualmente: `openclaw pipelines run [nombre]`
4. Ver logs del scheduler: `tail -50 /var/log/rentinlondon/agent.log | grep "scheduler"`

### ❌ WhatsApp no recibe mensajes
1. Verificar webhook de Meta: Meta Business Manager → Webhooks
2. Verificar que el servidor es accesible (si hay Tailscale, el webhook público debe estar configurado)
3. Verificar HMAC_SECRET coincide entre .env y configuración de Meta

### ❌ Lead duplicado creado
```sql
-- Encontrar duplicados por teléfono
SELECT telefono, COUNT(*), ARRAY_AGG(id) 
FROM leads 
GROUP BY telefono 
HAVING COUNT(*) > 1;

-- Fusionar: copiar interacciones al lead más antiguo, eliminar el duplicado
UPDATE interactions SET lead_id = 'uuid_lead_original' 
WHERE lead_id = 'uuid_duplicado';
DELETE FROM leads WHERE id = 'uuid_duplicado';
```

## Backups

### Backup manual de la base de datos
```bash
# Exportar via Supabase CLI
supabase db dump -f backup_$(date +%Y%m%d).sql

# O via pg_dump (requiere credenciales de Supabase DB)
pg_dump "$DATABASE_URL" > backup_$(date +%Y%m%d).sql
```

### Backup de archivos de configuración
```bash
# Crear archivo de backup (sin .env)
tar -czf rentinlondon-config-$(date +%Y%m%d).tar.gz \
  openclaw/config.yaml \
  openclaw/claw.config.json \
  supabase/config.toml \
  supabase/migrations/ \
  supabase/functions/
```

## Comandos de Telegram (resumen)

| Comando | Acción |
|---------|--------|
| `/reporte` | Reporte diario inmediato |
| `/leads hot` | Lista leads HOT activos |
| `/void` | Propiedades void y días |
| `/tokens` | Tokens por agente hoy |
| `/compliance` | Últimos compliance events |
| `/dormidos` | Leads dormidos 7d+ |
| `/snapshot` | Regenerar snapshot |
| `/pausar [agente]` | Pausar un agente |
| `/activar [agente]` | Activar un agente |
| `/pipeline [nombre]` | Ejecutar pipeline manualmente |
