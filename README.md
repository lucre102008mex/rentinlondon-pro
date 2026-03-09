# RentInLondon PRO 🏠🤖

Sistema de gestión inmobiliaria de nivel agencia internacional con **8 agentes de IA** (OpenClaw) + Supabase como fuente de verdad + Google Sheets como CRM visual.

---

## Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         RENTINLONDON PRO — ARQUITECTURA                      │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                        GATEWAY OPENCLAW (único)                          │ │
│  │                                                                           │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │ │
│  │  │   ALEX   │  │   IVY    │  │   ROSE   │  │   SALO   │  │ JEANETTE │  │ │
│  │  │Coordinad.│  │WhatsApp  │  │WhatsApp  │  │WhatsApp  │  │WhatsApp  │  │ │
│  │  │Reportes  │  │UK Intake │  │UK Ads    │  │UK Mrktpl │  │UK + Intl │  │ │
│  │  │Telegram  │  │Nurturing │  │Origin    │  │Origin    │  │Contratos │  │ │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘  │ │
│  │       │              │              │              │              │         │ │
│  │  ┌────┴──────────────┴──────────────┴──────────────┴──────────────┴────┐  │ │
│  │  │                     SUB-AGENTES (bajo consumo)                        │  │ │
│  │  │  ┌─────────────┐  ┌──────────────────┐  ┌────────────────────────┐  │  │ │
│  │  │  │   ADS-FB    │  │   ADS-GUMTREE    │  │    SCRIPT-RUNNER       │  │  │ │
│  │  │  │Facebook/IG  │  │Gumtree/Mrktplace │  │Normalización de datos  │  │  │ │
│  │  │  │Campañas     │  │Listings          │  │Reactivación leads      │  │  │ │
│  │  │  │CPL/CTR      │  │Vistas/Mensajes   │  │Validaciones            │  │  │ │
│  │  │  └─────────────┘  └──────────────────┘  └────────────────────────┘  │  │ │
│  │  └───────────────────────────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                           │
│                    ┌───────────────┼───────────────┐                          │
│                    ▼               ▼               ▼                          │
│             ┌────────────┐  ┌───────────┐  ┌────────────┐                    │
│             │  SUPABASE  │  │  GOOGLE   │  │ WHATSAPP   │                    │
│             │ PostgreSQL │  │  SHEETS   │  │   API      │                    │
│             │ RLS x rol  │  │ CRM visual│  │ (canales)  │                    │
│             │ Edge Funcs │  │ 7 pestañas│  │            │                    │
│             └─────┬──────┘  └───────────┘  └────────────┘                    │
│                   │                                                            │
│          ┌────────┴────────┐                                                  │
│          │ PIPELINES LOBSTER│                                                  │
│          │ daily-report    │                                                  │
│          │ weekly-report   │                                                  │
│          │ intl-handoff    │                                                  │
│          │ dormant-reactiv │                                                  │
│          │ cost-guard      │                                                  │
│          │ listings-refresh│                                                  │
│          └─────────────────┘                                                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Comparativa Supabase vs Firebase

| Característica               | **Supabase** ✅                        | Firebase                           |
|------------------------------|----------------------------------------|------------------------------------|
| Base de datos                | PostgreSQL (SQL completo)              | Firestore (NoSQL)                  |
| Row Level Security           | ✅ Nativo por rol                      | Reglas de seguridad manuales       |
| Triggers y funciones         | ✅ PL/pgSQL nativo                     | Cloud Functions (costo adicional)  |
| Edge Functions               | ✅ Deno/TypeScript                     | Cloud Functions (Node.js)          |
| Migraciones SQL              | ✅ Versionadas                        | ❌ No nativo                       |
| Joins y vistas SQL           | ✅ Completos                          | ❌ No existe                       |
| Tiempo real                  | ✅ Postgres LISTEN/NOTIFY             | ✅ WebSocket propio                |
| Precio base                  | Gratis hasta 500MB                    | Gratis limitado                    |
| Auth multifactor             | ✅ Incluido                           | ✅ Incluido                        |
| Open source                  | ✅ 100%                               | ❌ Propietario                     |
| Timezone en vistas           | ✅ AT TIME ZONE nativo               | ❌ Manual en cliente                |
| Compliance y auditoría       | ✅ RLS + audit trail SQL              | Complejo de implementar            |

---

## Estructura del Proyecto

```
rentinlondon-pro/
├── README.md
├── LICENSE
├── .gitignore
├── setup/
│   ├── 01-server-setup.sh
│   ├── 02-supabase-setup.sh
│   ├── 03-security-hardening.sh
│   ├── 04-tailscale-setup.sh
│   ├── identity_lock.sh
│   └── context_loader.sh
├── supabase/
│   ├── config.toml
│   ├── .env.example
│   ├── migrations/
│   │   ├── 00001_initial_schema.sql
│   │   └── 00002_zone_ranges_data.sql
│   └── functions/
│       ├── sync-to-sheets/
│       │   └── index.ts
│       └── webhook-receiver/
│           └── index.ts
├── openclaw/
│   ├── config.yaml
│   ├── claw.config.json
│   ├── .env.example
│   └── agents/
│       ├── alex/
│       ├── ivy/
│       ├── rose/
│       ├── salo/
│       ├── jeanette/
│       ├── ads-fb/
│       ├── ads-gumtree/
│       └── script-runner/
├── pipelines/
│   ├── daily-report.lobster
│   ├── weekly-report.lobster
│   ├── intl-handoff.lobster
│   ├── dormant-reactivation.lobster
│   ├── cost-guard.lobster
│   └── listings-refresh.lobster
├── shared/
│   ├── goal.md
│   ├── plan.md
│   ├── status.md
│   ├── leads-uk.md
│   ├── leads-intl-flag.md
│   ├── ads-report.md
│   └── log.md
|   ├── memory.md 
├── docs/
│   ├── ARCHITECTURE.md
│   ├── COMPLIANCE.md
│   ├── SCORING.md
│   ├── RUNBOOK.md
│   └── SECURITY.md
└── google-sheets/
    ├── SETUP.md
    └── sheets-template.json
```

---

## Instalación Completa — Paso a Paso

### Requisitos previos
- Ubuntu 22.04 LTS (VPS o servidor dedicado)
- Cuenta en [Supabase](https://supabase.com)
- Cuenta en [Google Cloud Console](https://console.cloud.google.com)
- Cuenta en [Meta Business](https://business.facebook.com) (para WhatsApp API)
- Cuenta en [Tailscale](https://tailscale.com)
- Node.js 20+ (se instala en Fase 2)

---

### FASE 1 — Clonar el repositorio

```bash
git clone https://github.com/TU_USUARIO/rentinlondon-pro.git
cd rentinlondon-pro
```

---

### FASE 2 — Preparar el servidor

```bash
chmod +x setup/01-server-setup.sh
sudo bash setup/01-server-setup.sh
```

**Qué hace:**
- `apt update && apt upgrade -y`
- Configura timezone a `Europe/London`
- Instala Docker + Docker Compose
- Instala NVM + Node 20 LTS
- Instala OpenClaw globalmente
- Crea estructura de directorios del proyecto

**Verificación:**
```bash
node --version       # v20.x.x
docker --version     # Docker 24.x+
openclaw --version   # OpenClaw x.x.x
timedatectl          # Time zone: Europe/London
```

---

### FASE 3 — Configurar Supabase

```bash
chmod +x setup/02-supabase-setup.sh
bash setup/02-supabase-setup.sh
```

**Qué hace:**
- Instala Supabase CLI
- Ejecuta `supabase login` (abre navegador)
- Inicializa el proyecto Supabase
- Vincula al proyecto remoto

**Pasos manuales adicionales:**
1. Ve a [supabase.com/dashboard](https://supabase.com/dashboard)
2. Crea un nuevo proyecto con nombre `rentinlondon-pro`
3. Anota el `Project ID` y la `anon key` y `service_role key`
4. Edita `supabase/config.toml` con tu `project_id`

---

### FASE 4 — Ejecutar migraciones SQL

```bash
cd /home/ubuntu/rentinlondon-pro
supabase db push
```

**O manualmente en el SQL Editor de Supabase:**
```bash
# Copiar y ejecutar en orden:
cat supabase/migrations/00001_initial_schema.sql
cat supabase/migrations/00002_zone_ranges_data.sql
```

**Verificación en Supabase Dashboard:**
- Tabla `leads` con todos los campos incluyendo `urgency_score`, `data_completeness`, `budget_fit`
- Tabla `zone_ranges` con 30+ zonas de Londres
- Vistas: `v_leads_activos`, `v_leads_dormantes`, `v_propiedades_void`, `v_daily_summary`
- Triggers: `update_updated_at`, `calculate_urgency_score`, `calculate_data_completeness`
- RLS habilitado en todas las tablas

---

### FASE 5 — Configurar variables de entorno

```bash
# Supabase
cp supabase/.env.example supabase/.env
nano supabase/.env

# OpenClaw
cp openclaw/.env.example openclaw/.env
nano openclaw/.env
```

**Variables requeridas en `supabase/.env`:**
```env
SUPABASE_URL=https://TUPROYECTO.supabase.co
SUPABASE_ANON_KEY=tu_anon_key
SUPABASE_SERVICE_ROLE_KEY=tu_service_role_key
GOOGLE_SA_EMAIL=tu-service-account@proyecto.iam.gserviceaccount.com
GOOGLE_SA_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"
GOOGLE_SHEETS_ID=tu_spreadsheet_id
WEBHOOK_HMAC_SECRET=genera_con_openssl_rand_hex_32
```

**Variables requeridas en `openclaw/.env`:**
```env
GATEWAY_PORT=3000
SUPABASE_URL=https://TUPROYECTO.supabase.co
SUPABASE_ANON_KEY=tu_anon_key
WHATSAPP_API_URL=https://graph.facebook.com/v18.0
WHATSAPP_TOKEN=tu_whatsapp_business_token
WHATSAPP_PHONE_ID=tu_phone_number_id
TELEGRAM_BOT_TOKEN=tu_telegram_bot_token
TELEGRAM_CHAT_ID=chat_id_del_dueno
HMAC_SECRET=misma_clave_que_supabase_hmac_secret
```

---

### FASE 6 — Desplegar Edge Functions

```bash
# Desplegar función de sincronización con Google Sheets
supabase functions deploy sync-to-sheets

# Desplegar webhook receptor
supabase functions deploy webhook-receiver

# Configurar secrets en Supabase Edge Functions
supabase secrets set GOOGLE_SA_EMAIL="tu-sa@proyecto.iam.gserviceaccount.com"
supabase secrets set GOOGLE_SA_PRIVATE_KEY="$(cat google-sa-key.pem)"
supabase secrets set GOOGLE_SHEETS_ID="tu_spreadsheet_id"
supabase secrets set WEBHOOK_HMAC_SECRET="tu_hmac_secret"
```

---

### FASE 7 — Configurar Google Sheets

1. Sigue las instrucciones en `google-sheets/SETUP.md`
2. Crea la hoja de cálculo en Google Sheets
3. Importa el template `google-sheets/sheets-template.json`
4. Configura la cuenta de servicio con acceso de Editor

**Pestañas del CRM:**
- `Leads UK` — Leads del mercado británico
- `Leads Internacionales` — Leads internacionales
- `Propiedades` — Listado de propiedades
- `Viewings` — Visitas programadas
- `Contratos` — Contratos activos
- `Ads Report` — Rendimiento de campañas
- `Weekly Summary` — Resumen semanal

---

### FASE 8 — Iniciar OpenClaw Gateway

```bash
cd /home/ubuntu/rentinlondon-pro/openclaw
openclaw start --config config.yaml
```

**Verificar que los 8 agentes están activos:**
```bash
openclaw status
```

Esperado:
```
✅ alex        — ACTIVE  | Channel: telegram
✅ ivy         — ACTIVE  | Channel: whatsapp
✅ rose        — ACTIVE  | Channel: whatsapp
✅ salo        — ACTIVE  | Channel: whatsapp
✅ jeanette    — ACTIVE  | Channel: whatsapp
✅ ads-fb      — ACTIVE  | Channel: webhook
✅ ads-gumtree — ACTIVE  | Channel: webhook
✅ script-runner— ACTIVE | Channel: internal
```

---

### FASE 9 — Seguridad y acceso remoto

```bash
# Configurar UFW y fail2ban
chmod +x setup/03-security-hardening.sh
sudo bash setup/03-security-hardening.sh

# Instalar Tailscale
chmod +x setup/04-tailscale-setup.sh
sudo bash setup/04-tailscale-setup.sh

# Bloquear archivos de identidad de agentes
chmod +x setup/identity_lock.sh
bash setup/identity_lock.sh
```

**Verificación de seguridad:**
```bash
sudo ufw status           # Reglas UFW activas
sudo fail2ban-client status  # fail2ban activo
tailscale status          # Conectado a red Tailscale
ls -la openclaw/agents/alex/  # SOUL.md con permisos 444
```

---

### FASE 10 — Activar pipelines y verificar sistema

```bash
# Verificar pipelines con OpenClaw
openclaw pipelines list

# Ejecutar prueba del reporte diario
openclaw pipelines run daily-report --test

# Cargar contexto para Alex
chmod +x setup/context_loader.sh
bash setup/context_loader.sh
```

**Verificación final del sistema:**
```bash
# Revisar logs de agentes
tail -f /var/log/rentinlondon/agent.log

# Verificar snapshot generado
ls -la shared/snapshots/

# Test del webhook con HMAC
PAYLOAD='{"test":true}'
SECRET="TU_HMAC_SECRET"
SIG=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" -binary | xxd -p -c 256)
curl -X POST https://TUPROYECTO.supabase.co/functions/v1/webhook-receiver \
  -H "Content-Type: application/json" \
  -H "X-Signature: sha256=$SIG" \
  -d "$PAYLOAD"
```

---

## Checklist de Verificación por Fase

### Fase 1 — Repositorio
- [ ] Repositorio clonado correctamente
- [ ] Todos los archivos presentes (estructura verificada)
- [ ] `.env` archivos copiados desde `.env.example`

### Fase 2 — Servidor
- [ ] Node.js 20+ instalado
- [ ] Docker y Docker Compose funcionando
- [ ] OpenClaw instalado globalmente
- [ ] Timezone configurada a Europe/London
- [ ] Directorios del proyecto creados

### Fase 3 — Supabase CLI
- [ ] Supabase CLI instalado
- [ ] Login exitoso
- [ ] Proyecto creado en dashboard
- [ ] `project_id` actualizado en `config.toml`

### Fase 4 — Base de datos
- [ ] Migración 00001 ejecutada sin errores
- [ ] Migración 00002 ejecutada (30+ zonas insertadas)
- [ ] Todos los triggers funcionando
- [ ] Todas las vistas creadas
- [ ] RLS habilitado en todas las tablas

### Fase 5 — Variables de entorno
- [ ] `supabase/.env` configurado con todas las claves
- [ ] `openclaw/.env` configurado con todos los tokens
- [ ] HMAC_SECRET generado con `openssl rand -hex 32`
- [ ] Google Service Account configurado

### Fase 6 — Edge Functions
- [ ] `sync-to-sheets` desplegada y activa
- [ ] `webhook-receiver` desplegada y activa
- [ ] Secrets configurados en Supabase

### Fase 7 — Google Sheets
- [ ] Hoja de cálculo creada con 7 pestañas
- [ ] Service Account tiene acceso de Editor
- [ ] Sincronización automática funcionando

### Fase 8 — Agentes
- [ ] Gateway OpenClaw iniciado
- [ ] Los 8 agentes reportan ACTIVE
- [ ] SOUL.md e IDENTITY.md cargados correctamente
- [ ] Canales WhatsApp y Telegram conectados

### Fase 9 — Seguridad
- [ ] UFW configurado (solo SSH + Tailscale)
- [ ] fail2ban activo para SSH
- [ ] Tailscale instalado y conectado
- [ ] Archivos SOUL/IDENTITY bloqueados (chmod 444)
- [ ] `.env` con permisos 600

### Fase 10 — Pipelines y verificación
- [ ] 6 pipelines registrados en OpenClaw
- [ ] daily-report se ejecuta a las 8 AM London
- [ ] intl-handoff se ejecuta cada 30 min
- [ ] Logs del sistema visibles
- [ ] Snapshot de contexto generado para Alex

---

## Agentes del Sistema

| Agente           | Canal       | Rol                                              | Acceso DB               |
|------------------|-------------|--------------------------------------------------|-------------------------|
| **Alex**         | Telegram    | Coordinador, reportes, alertas, auditoría        | Lectura amplia          |
| **Ivy**          | WhatsApp    | UK intake y nurturing de leads                   | Leads UK + interactions |
| **Rose**         | WhatsApp    | UK leads de ads, seguimientos                    | Leads UK + interactions |
| **Salo**         | WhatsApp    | UK leads de marketplaces, intake rápido          | Leads UK + interactions |
| **Jeanette**     | WhatsApp    | UK + internacionales, contratos remotos, R2R     | Leads + contratos       |
| **ads-fb**       | Webhook     | Facebook/Instagram campaigns, CPL/CTR            | Insertar leads FB       |
| **ads-gumtree**  | Webhook     | Gumtree listings, vistas/mensajes                | Insertar leads Gumtree  |
| **script-runner**| Internal    | Normalización, reactivación (con aprobación)     | Vistas + agent_logs     |

---

## Compliance y Seguridad

### UK Equality Act 2010
El sistema cumple al 100% con la legislación de igualdad del Reino Unido:
- **Scoring basado únicamente en**: urgencia de mudanza, completitud de datos, ajuste de presupuesto al mercado
- **Atributos protegidos EXCLUIDOS**: edad, discapacidad, reasignación de género, matrimonio/unión civil, embarazo/maternidad, raza, religión/creencias, sexo, orientación sexual
- **Auditoría completa**: toda decisión queda registrada en `compliance_audit`

### GDPR
- Datos personales mínimos necesarios
- Propósito documentado por campo
- Derecho al olvido implementable con `DELETE` en `leads`
- Logs de acceso en `agent_logs`

---

## Comandos Útiles

```bash
# Ver estado de agentes
openclaw status

# Ver logs en tiempo real
tail -f /var/log/rentinlondon/agent.log

# Ejecutar un pipeline manualmente
openclaw pipelines run daily-report

# Cargar contexto para Alex
bash setup/context_loader.sh

# Aplicar nuevas migraciones
supabase db push

# Ver snapshot más reciente
cat shared/snapshots/$(ls -t shared/snapshots/ | head -1)

# Desplegar Edge Function actualizada
supabase functions deploy sync-to-sheets

# Ver leads activos en Supabase
curl -s "https://TUPROYECTO.supabase.co/rest/v1/v_leads_activos" \
  -H "apikey: TU_ANON_KEY" \
  -H "Authorization: Bearer TU_ANON_KEY"
```

---

## Soporte

Este proyecto está diseñado para agencias inmobiliarias en el mercado londinense. Para personalización o soporte técnico, revisa la documentación en `docs/`.

- `docs/ARCHITECTURE.md` — Diagramas y flujos detallados
- `docs/COMPLIANCE.md` — Detalles de cumplimiento legal UK
- `docs/SCORING.md` — Algoritmos de scoring sin sesgo
- `docs/RUNBOOK.md` — Guía operativa completa
- `docs/SECURITY.md` — Guía de seguridad y hardening

---

**Licencia**: MIT | **Timezone**: Europe/London | **Compliance**: UK Equality Act 2010 + GDPR
