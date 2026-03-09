#!/usr/bin/env bash
# =============================================================================
# RentInLondon PRO — Fase 4: Instalación de Tailscale para acceso remoto
# =============================================================================
set -euo pipefail

YELLOW='\033[1;33m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${YELLOW}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && error "Ejecutar como root: sudo bash $0"

# ─── 1. Instalar Tailscale ────────────────────────────────────────────────────
info "Instalando Tailscale..."
if ! command -v tailscale &>/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
success "Tailscale instalado: $(tailscale version)"

# ─── 2. Habilitar y arrancar el servicio ─────────────────────────────────────
info "Habilitando servicio Tailscale..."
systemctl enable tailscaled
systemctl start tailscaled
success "tailscaled activo"

# ─── 3. Autenticar con Tailscale ─────────────────────────────────────────────
echo ""
info "Para conectar este servidor a tu red Tailscale, ejecuta:"
echo ""
echo "  sudo tailscale up --hostname rentinlondon-pro-server"
echo ""
echo "Esto generará un enlace de autenticación que debes abrir en tu navegador."
echo "Después de autenticar, el servidor se conectará automáticamente."
echo ""
read -rp "¿Deseas autenticar ahora? (s/N): " AUTH_NOW

if [[ "${AUTH_NOW,,}" == "s" ]]; then
  tailscale up --hostname rentinlondon-pro-server --accept-routes
  success "Tailscale conectado"
  echo ""
  echo "Estado de Tailscale:"
  tailscale status
else
  info "Recuerda ejecutar: sudo tailscale up --hostname rentinlondon-pro-server"
fi

# ─── 4. Configurar UFW para permitir interfaz Tailscale ──────────────────────
info "Configurando UFW para Tailscale..."
ufw allow in on tailscale0 comment 'Tailscale network' 2>/dev/null || true
success "Regla UFW para tailscale0 añadida"

# ─── 5. Configurar ACL de Tailscale (instrucciones) ──────────────────────────
echo ""
info "PASO ADICIONAL RECOMENDADO — Configurar ACL de Tailscale:"
echo ""
echo "  1. Ve a: https://login.tailscale.com/admin/acls"
echo "  2. Agrega estas ACL para restringir acceso:"
echo ""
cat << 'TAILSCALE_ACL'
{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:admin"],
      "dst": ["tag:rentinlondon-server:3000", "tag:rentinlondon-server:8080"]
    }
  ],
  "tagOwners": {
    "tag:admin": ["autogroup:owner"],
    "tag:rentinlondon-server": ["autogroup:owner"]
  }
}
TAILSCALE_ACL

success "=== Fase 4 completa ==="
echo ""
echo "Siguiente paso: bash setup/identity_lock.sh"
