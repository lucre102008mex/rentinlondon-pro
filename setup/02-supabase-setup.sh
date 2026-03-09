#!/usr/bin/env bash
# =============================================================================
# RentInLondon PRO — Fase 2: Instalación y configuración de Supabase CLI
# =============================================================================
set -euo pipefail

YELLOW='\033[1;33m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${YELLOW}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

PROJECT_DIR="${PROJECT_DIR:-/home/ubuntu/rentinlondon-pro}"

# ─── 1. Instalar Supabase CLI ─────────────────────────────────────────────────
info "Instalando Supabase CLI..."
if ! command -v supabase &>/dev/null; then
  SUPABASE_VERSION="1.176.8"
  ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
  case "$ARCH" in
    amd64|x86_64) SUPABASE_ARCH="linux_amd64" ;;
    arm64|aarch64) SUPABASE_ARCH="linux_arm64" ;;
    *) error "Arquitectura no soportada: $ARCH" ;;
  esac
  
  DOWNLOAD_URL="https://github.com/supabase/cli/releases/download/v${SUPABASE_VERSION}/supabase_${SUPABASE_ARCH}.tar.gz"
  info "Descargando Supabase CLI v${SUPABASE_VERSION}..."
  curl -fsSL "$DOWNLOAD_URL" -o /tmp/supabase.tar.gz
  tar -xzf /tmp/supabase.tar.gz -C /tmp
  mv /tmp/supabase /usr/local/bin/supabase
  chmod +x /usr/local/bin/supabase
  rm /tmp/supabase.tar.gz
fi
success "Supabase CLI: $(supabase --version)"

# ─── 2. Verificar que el proyecto existe ─────────────────────────────────────
if [[ ! -d "$PROJECT_DIR/supabase" ]]; then
  error "No se encontró $PROJECT_DIR/supabase. Ejecuta primero: bash setup/01-server-setup.sh"
fi

cd "$PROJECT_DIR"

# ─── 3. Login a Supabase ─────────────────────────────────────────────────────
info "Iniciando sesión en Supabase..."
echo ""
echo "Se abrirá el navegador para autenticación. Si estás en servidor sin GUI,"
echo "usa: supabase login --no-browser"
echo ""
read -rp "¿Usar modo sin navegador? (s/N): " NO_BROWSER
if [[ "${NO_BROWSER,,}" == "s" ]]; then
  supabase login --no-browser
else
  supabase login
fi
success "Login exitoso"

# ─── 4. Solicitar Project ID ──────────────────────────────────────────────────
echo ""
info "Necesitas el Project ID de tu proyecto Supabase."
echo "Puedes encontrarlo en: https://supabase.com/dashboard -> Tu proyecto -> Settings -> General"
echo ""
read -rp "Ingresa tu Supabase Project ID: " SUPABASE_PROJECT_ID

if [[ -z "$SUPABASE_PROJECT_ID" ]]; then
  error "Project ID no puede estar vacío"
fi

# ─── 5. Actualizar config.toml ───────────────────────────────────────────────
info "Actualizando supabase/config.toml con project_id..."
sed -i "s/project_id = \"TU_PROJECT_ID\"/project_id = \"$SUPABASE_PROJECT_ID\"/" \
  "$PROJECT_DIR/supabase/config.toml" || true
success "config.toml actualizado"

# ─── 6. Vincular al proyecto remoto ──────────────────────────────────────────
info "Vinculando al proyecto remoto de Supabase..."
supabase link --project-ref "$SUPABASE_PROJECT_ID"
success "Proyecto vinculado"

# ─── 7. Verificar conexión ───────────────────────────────────────────────────
info "Verificando conexión con Supabase..."
supabase projects list
success "=== Fase 2 completa ==="

echo ""
echo "Siguiente paso:"
echo "  1. Edita supabase/.env con tus claves (supabase/.env.example como referencia)"
echo "  2. Ejecuta: supabase db push"
echo "  3. Después: bash setup/03-security-hardening.sh"
