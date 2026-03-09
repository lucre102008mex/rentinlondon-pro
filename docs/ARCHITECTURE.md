# ARCHITECTURE.md — RentInLondon PRO

## Diagrama General del Sistema

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                        RENTINLONDON PRO — ARQUITECTURA                        ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║  CANALES DE ENTRADA                                                           ║
║  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐  ┌──────────────────┐ ║
║  │  WhatsApp   │  │  Facebook/   │  │   Gumtree/    │  │    Telegram      │ ║
║  │  Business   │  │  Instagram   │  │  Marketplaces │  │   (solo Alex)    │ ║
║  │   API       │  │  Lead Ads    │  │   Webhooks    │  │                  │ ║
║  └──────┬──────┘  └──────┬───────┘  └───────┬───────┘  └────────┬─────────┘ ║
║         │                │                   │                    │           ║
║         ▼                ▼                   ▼                    ▼           ║
║  ╔══════════════════════════════════════════════════════════════════════════╗ ║
║  ║                    OPENCLAW GATEWAY (puerto 3000)                        ║ ║
║  ║                    HMAC verification en todos los webhooks               ║ ║
║  ╠══════════════════════════════════════════════════════════════════════════╣ ║
║  ║                                                                           ║ ║
║  ║  AGENTES PRINCIPALES                                                      ║ ║
║  ║  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐  ║ ║
║  ║  │   ALEX   │ │   IVY    │ │   ROSE   │ │   SALO   │ │  JEANETTE    │  ║ ║
║  ║  │Telegram  │ │WhatsApp  │ │WhatsApp  │ │WhatsApp  │ │  WhatsApp    │  ║ ║
║  ║  │Coordinad.│ │UK Intake │ │UK Ads    │ │UK Mrktpl │ │  UK + Intl   │  ║ ║
║  ║  │Reportes  │ │Nurturing │ │Facebook/ │ │Gumtree/  │ │  Contratos   │  ║ ║
║  ║  │No leads  │ │Calificar │ │Instagram │ │Rightmove │ │  R2R         │  ║ ║
║  ║  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └──────┬───────┘  ║ ║
║  ║       │             │             │             │              │           ║ ║
║  ║  SUB-AGENTES (bajo consumo)                                               ║ ║
║  ║  ┌──────────────┐ ┌──────────────────┐ ┌──────────────────────────────┐  ║ ║
║  ║  │   ADS-FB     │ │   ADS-GUMTREE    │ │      SCRIPT-RUNNER           │  ║ ║
║  ║  │Facebook/IG   │ │Gumtree/Rightmove │ │ Normalización datos           │  ║ ║
║  ║  │Campañas      │ │Zoopla/SpareRoom  │ │ Reactivación (con aprobación) │  ║ ║
║  ║  │CPL/CTR/Leads │ │Listings refresh  │ │ Validación compliance         │  ║ ║
║  ║  │Derivar→WA    │ │Derivar→WA        │ │ Solo canal interno            │  ║ ║
║  ║  └──────────────┘ └──────────────────┘ └──────────────────────────────┘  ║ ║
║  ║                                                                           ║ ║
║  ╚══════════════════════════════════════════════════════════════════════════╝ ║
║                │                                                              ║
║     ┌──────────┼──────────────┐                                              ║
║     ▼          ▼              ▼                                              ║
║  ┌──────────┐ ┌────────────┐ ┌─────────────────────────────────────────┐    ║
║  │ SUPABASE │ │  GOOGLE    │ │      EDGE FUNCTIONS                     │    ║
║  │PostgreSQL│ │  SHEETS    │ │  sync-to-sheets (JWT RS256 + HMAC)     │    ║
║  │RLS/agente│ │ 7 pestañas │ │  webhook-receiver (HMAC SHA-256)       │    ║
║  │Triggers  │ │CRM visual  │ └─────────────────────────────────────────┘    ║
║  │Vistas    │ │            │                                                  ║
║  │Views LDN │ │Sync cada   │                                                  ║
║  └──────────┘ │6 horas     │                                                  ║
║               └────────────┘                                                  ║
║                                                                               ║
║  PIPELINES PROGRAMADOS (Lobster)                                              ║
║  ┌──────────────────────────────────────────────────────────────────────────┐ ║
║  │ daily-report     : Lun-Vie 8 AM London                                   │ ║
║  │ weekly-report    : Lunes 9 AM London                                     │ ║
║  │ intl-handoff     : Cada 30 minutos                                       │ ║
║  │ dormant-reactiv  : Miércoles 10 AM London                                │ ║
║  │ cost-guard       : Diario 10 PM London                                   │ ║
║  │ listings-refresh : Lunes y Jueves 11 AM London                           │ ║
║  └──────────────────────────────────────────────────────────────────────────┘ ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

## Flujos de Datos

### Flujo: Lead UK via WhatsApp
```
Lead envía mensaje → WhatsApp Business API
       ↓
OpenClaw Gateway (verifica HMAC si viene de webhook)
       ↓
Router: ¿canal_origen?
  facebook/instagram → Rose
  gumtree/marketplace → Salo
  whatsapp directo → Ivy
       ↓
Agente recibe mensaje, CREATE en leads (Supabase)
       ↓
Triggers automáticos:
  - urgency_score (fecha_mudanza + response_speed)
  - data_completeness (campos obligatorios)
  - budget_fit (vs zone_ranges)
       ↓
Agente responde, INSERT en interactions
       ↓
Si es_internacional → escalado a Jeanette (intl-handoff)
       ↓
Si califica → schedule viewing (INSERT en viewings)
       ↓
Sync automático a Google Sheets cada 6h
```

### Flujo: Lead Internacional
```
Lead detectado (es_internacional = TRUE)
       ↓
intl-handoff pipeline (cada 30 min)
  → UPDATE leads.asignado_a = 'jeanette'
  → UPDATE leads.escalado_jeanette = TRUE
       ↓
Jeanette recibe notificación interna
       ↓
Jeanette inicia secuencia internacional:
  1. Bienvenida contextual
  2. Schedule video tour
  3. Solicitar documentos R2R
  4. Verificar R2R (Home Office guidance)
  5. Preparar contrato
  6. Firma electrónica
  7. Pre-arrival guide
       ↓
UPDATE contracts (todos los campos R2R)
UPDATE leads.status = 'contrato_firmado'
Notify Alex
```

### Flujo: Reporte Diario
```
8:00 AM London (Lun-Vie)
       ↓
Alex carga snapshot de context_loader.sh
       ↓
Consulta v_daily_summary, v_leads_activos,
v_propiedades_void, agent_logs tokens
       ↓
Genera reporte formateado en Markdown
       ↓
Envía por Telegram al dueño
       ↓
INSERT en weekly_summaries (acumulado)
```

## Esquema de Base de Datos

```
leads ──────────────── interactions
  │                         │
  ├── viewings ─────── properties
  │         │
  ├── contracts
  │
  ├── listings_history ── properties
  │
  ├── agent_logs
  ├── compliance_audit
  ├── weekly_summaries
  └── zone_ranges (referencia para budget_fit)
```

## Seguridad por Capas

```
Capa 1: Red
  UFW → solo SSH + Tailscale
  Tailscale VPN → acceso administrativo

Capa 2: Aplicación
  HMAC SHA-256 → todos los webhooks externos
  JWT RS256 → Edge Functions a Google Sheets

Capa 3: Base de datos
  RLS por agente en Supabase
  service_role solo en Edge Functions
  Políticas separadas por agente_id en JWT

Capa 4: Archivos
  .env con chmod 600
  SOUL.md/IDENTITY.md con chmod 444
```

## Escalabilidad

El sistema está diseñado para escalar:
- **Más propiedades**: Solo agregar a la tabla `properties`
- **Más zonas**: Agregar filas a `zone_ranges`
- **Más agentes**: Agregar al `config.yaml` y crear carpeta de agente
- **Más canales**: Agregar binding en `claw.config.json`
- **Más campañas**: ads-fb gestiona múltiples campañas simultáneamente
