#!/usr/bin/env bash
# =============================================================================
# RentInLondon PRO — Cargador de contexto para Alex
# Consulta Supabase, genera snapshot en shared/snapshots/
# =============================================================================
set -euo pipefail

YELLOW='\033[1;33m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${YELLOW}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ─── Configuración ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SNAP_DIR="$PROJECT_DIR/shared/snapshots"
ENV_FILE="$PROJECT_DIR/supabase/.env"

# Cargar variables de entorno
if [[ -f "$ENV_FILE" ]]; then
  set -a; source "$ENV_FILE"; set +a
else
  error "No se encontró $ENV_FILE. Configura las variables de entorno primero."
fi

: "${SUPABASE_URL:?Variable SUPABASE_URL no configurada}"
: "${SUPABASE_ANON_KEY:?Variable SUPABASE_ANON_KEY no configurada}"

TIMESTAMP=$(TZ="Europe/London" date '+%Y-%m-%dT%H:%M:%S')
DATE=$(TZ="Europe/London" date '+%Y-%m-%d')
SNAP_FILE="$SNAP_DIR/snapshot_${DATE}.md"

mkdir -p "$SNAP_DIR"

info "Generando snapshot de contexto: $SNAP_FILE"

# ─── Función para consultar Supabase REST API ─────────────────────────────────
supabase_query() {
  local endpoint="$1"
  local params="${2:-}"
  curl -fsSL \
    "${SUPABASE_URL}/rest/v1/${endpoint}${params}" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
    -H "Accept: application/json" 2>/dev/null || echo "[]"
}

# ─── Consultar vistas ─────────────────────────────────────────────────────────
info "Consultando v_daily_summary..."
DAILY_SUMMARY=$(supabase_query "v_daily_summary" "?limit=1")

info "Consultando v_leads_activos..."
LEADS_ACTIVOS=$(supabase_query "v_leads_activos" "?limit=50&order=urgency_score.desc")

info "Consultando v_propiedades_void..."
PROPS_VOID=$(supabase_query "v_propiedades_void" "?limit=20")

info "Consultando v_leads_dormantes..."
LEADS_DORMANTES=$(supabase_query "v_leads_dormantes" "?limit=20")

# ─── Parsear con Python ───────────────────────────────────────────────────────
python3 << PYEOF
import json, sys, os

timestamp = "$TIMESTAMP"
date = "$DATE"

def safe_json(s):
    try:
        return json.loads(s)
    except:
        return []

daily = safe_json('''$DAILY_SUMMARY''')
activos = safe_json('''$LEADS_ACTIVOS''')
void_props = safe_json('''$PROPS_VOID''')
dormantes = safe_json('''$LEADS_DORMANTES''')

d = daily[0] if daily else {}

lines = [
    f"# Snapshot de Contexto — RentInLondon PRO",
    f"**Generado**: {timestamp} (Europe/London)",
    f"**Fecha**: {date}",
    "",
    "---",
    "",
    "## Resumen Diario (v_daily_summary)",
    "",
    f"| Métrica | Valor |",
    f"|---------|-------|",
    f"| Leads nuevos hoy | {d.get('leads_nuevos_hoy', 'N/A')} |",
    f"| Leads activos total | {d.get('leads_activos_total', 'N/A')} |",
    f"| Leads hot (score 4-5) | {d.get('leads_hot', 'N/A')} |",
    f"| Leads warm (score 2-3) | {d.get('leads_warm', 'N/A')} |",
    f"| Leads cold (score 0-1) | {d.get('leads_cold', 'N/A')} |",
    f"| Leads internacionales | {d.get('leads_internacionales', 'N/A')} |",
    f"| Viewings hoy | {d.get('viewings_hoy', 'N/A')} |",
    f"| Contratos activos | {d.get('contratos_activos', 'N/A')} |",
    f"| Propiedades void | {d.get('propiedades_void', 'N/A')} |",
    "",
    "---",
    "",
    "## Leads Activos (Top 20 por urgency_score)",
    "",
    "| Nombre | Zona | Presupuesto | Score | Budget Fit | Asignado a |",
    "|--------|------|-------------|-------|------------|------------|",
]

for l in activos[:20]:
    lines.append(
        f"| {l.get('nombre','?')} | {l.get('zona_preferida','?')} | "
        f"£{l.get('presupuesto_max',0):,} | {l.get('urgency_score','?')} | "
        f"{l.get('budget_fit','?')} | {l.get('asignado_a','?')} |"
    )

lines += [
    "",
    "---",
    "",
    "## Propiedades Disponibles (Void)",
    "",
    "| Dirección | Tipo | Precio | Zona | Días Void |",
    "|-----------|------|--------|------|-----------|",
]
for p in void_props[:15]:
    lines.append(
        f"| {p.get('direccion','?')} | {p.get('tipo','?')} | "
        f"£{p.get('precio_mensual',0):,}/mo | {p.get('zona','?')} | "
        f"{p.get('dias_void',0)} |"
    )

lines += [
    "",
    "---",
    "",
    "## Leads Dormantes (sin contacto 7+ días)",
    "",
    "| Nombre | Último contacto | Score | Asignado a |",
    "|--------|-----------------|-------|------------|",
]
for l in dormantes[:10]:
    lines.append(
        f"| {l.get('nombre','?')} | {l.get('ultima_interaccion','?')} | "
        f"{l.get('urgency_score','?')} | {l.get('asignado_a','?')} |"
    )

lines += [
    "",
    "---",
    "",
    f"*Snapshot generado automáticamente por context_loader.sh — {timestamp}*",
]

content = "\n".join(lines)
with open("$SNAP_FILE", "w") as f:
    f.write(content)

leads_count = len(activos)
void_count = len(void_props)
dormantes_count = len(dormantes)
print(f"Resumen del snapshot:")
print(f"  Leads activos incluidos : {leads_count}")
print(f"  Propiedades void        : {void_count}")
print(f"  Leads dormantes         : {dormantes_count}")
print(f"  Total líneas generadas  : {len(lines)}")
print(f"\n[Snapshot guardado en: $SNAP_FILE]")
PYEOF

# ─── Mantener solo últimos 30 snapshots ──────────────────────────────────────
info "Limpiando snapshots antiguos (manteniendo últimos 30)..."
ls -t "$SNAP_DIR"/snapshot_*.md 2>/dev/null | tail -n +31 | xargs rm -f 2>/dev/null || true

success "=== Snapshot generado exitosamente ==="
echo ""
echo "Archivo: $SNAP_FILE"
echo "Tamaño: $(wc -l < "$SNAP_FILE") líneas"
