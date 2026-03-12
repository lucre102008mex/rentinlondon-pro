# ARCHITECTURE.md — RentInLondon PRO

## Diagrama General del Sistema

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                        RENTINLONDON PRO — ARQUITECTURA                        ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║  FASE 1: GENERACIÓN (SUB-AGENTES PUBLICITARIOS)                               ║
║  ┌──────────────────┐      ┌──────────────────────────┐                       ║
║  │   ADS-FB         │      │      ADS-GUMTREE         │                       ║
║  │ Posteo FB/IG     │      │ Listings Marketplaces    │                       ║
║  │ (1 agente x post)│      │ (1 agente x listing)     │                       ║
║  └────────┬─────────┘      └────────────┬─────────────┘                       ║
║           │ (tracking ROI)              │ (tracking ROI)                      ║
║           ▼                             ▼                                     ║
║  FASE 2: ATENCIÓN Y CONVERSIÓN (EQUIPO DE VENTAS - WhatsApp)                  ║
║  ┌──────────────┐  ┌───────────────┐  ┌───────────┐  ┌──────────────┐         ║
║  │     IVY      │  │     ROSE      │  │   SALO    │  │   JEANETTE   │         ║
║  │ MULTICANAL   │  │ MULTICANAL    │  │ MULTICANAL│  │ MULTICANAL   │         ║
║  └───────┬──────┘  └───────┬───────┘  └─────┬─────┘  └──────┬───────┘         ║
║          │                 │                │               │                 ║
║          └─────────────────┴──────┬─────────┴───────────────┘                 ║
║                                   ▼                                           ║
║  FASE 3: CIERRE (FÍSICO/LEGAL)    ┌──────────────────────────────────────┐    ║
║                                   │ 154 Bishopsgate (Office Appt)        │    ║
║                                   │ SCL Score >= 7 mandatorio            │    ║
║                                   └──────────────────────────────────────┘    ║
║                                                                               ║
║  COORDINACIÓN Y CONTROL           ┌──────────┐                                ║
║                                   │   ALEX   │                                ║
║                                   │ Telegram │                                ║
║                                   │ Reportes │                                ║
║                                   └──────────┘                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

## Flujos de Datos

### Flujo: Lead UK via WhatsApp
```
Lead envía mensaje → WhatsApp (WhatsApp de agente específica)
       ↓
OpenClaw Gateway (verifica HMAC si viene de webhook)
       ↓
Asignación Dinámica por Campaña:
  - El lead llega a la agente cuyo número estaba en el post específico.
  - canal_origen se detecta por el contexto del mensaje (CTWA/Portal text).
       ↓
Agente recibe mensaje, CREATE en leads (Supabase) con SCL v7.5 Ultra
       ↓
Triggers automáticos (Scoring SCL 0-10):
  - urgency_score (move_date logic: urgent < 14d)
  - data_completeness (name, budget, income, slot)
  - budget_fit (vs market_ranges Z1-Z6)
       ↓
Agente responde, INSERT en interactions
       ↓
Si prefijo != +44 → handoff a Jeanette
       ↓
Si califica → schedule viewing (INSERT en viewings)
       ↓
Sync automático a Google Sheets cada 6h
```

### Flujo: Lead Internacional
```
Lead detectado como internacional (prefijo != +44)
       ↓
Transferencia de contexto (handoff)
  - La agente inicial presenta a Jeanette formalmente.
  - Jeanette asume la conversación en WhatsApp.
       ↓
Jeanette aplica secuencia internacional:
  1. Bienvenida y validación de nacionalidad
  2. Ofrecer Video Tours (evita desplazamiento inicial)
  3. Solicitud de Passport/Share Code (Right to Rent)
  4. Pre-calificación técnica y legal
  5. Cierre mediante reserva remota o cita en oficina
       ↓
UPDATE contracts (campos R2R verificados)
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
