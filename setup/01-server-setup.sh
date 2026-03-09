#!/usr/bin/env bash
# =============================================================================
# RentInLondon PRO — Fase 1: Preparación del servidor Ubuntu 22.04 LTS
# =============================================================================
set -euo pipefail

YELLOW='\033[1;33m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${YELLOW}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && error "Ejecutar como root: sudo bash $0"

PROJECT_DIR="/home/ubuntu/rentinlondon-pro"
LOG_DIR="/var/log/rentinlondon"
SNAP_DIR="$PROJECT_DIR/shared/snapshots"

# ─── 1. Actualizar sistema ────────────────────────────────────────────────────
info "Actualizando sistema..."
apt-get update -y && apt-get upgrade -y
apt-get install -y curl wget git unzip build-essential software-properties-common \
  ca-certificates gnupg lsb-release jq openssl python3 python3-pip xxd
success "Sistema actualizado"

# ─── 2. Configurar timezone ───────────────────────────────────────────────────
info "Configurando timezone a Europe/London..."
timedatectl set-timezone Europe/London
success "Timezone: $(timedatectl | grep 'Time zone')"

# ─── 3. Instalar Docker ───────────────────────────────────────────────────────
info "Instalando Docker..."
if ! command -v docker &>/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable docker && systemctl start docker
  usermod -aG docker ubuntu 2>/dev/null || true
fi
success "Docker: $(docker --version)"

# ─── 4. Instalar NVM + Node 20 ───────────────────────────────────────────────
info "Instalando NVM y Node 20 LTS..."
if [[ ! -d /home/ubuntu/.nvm ]]; then
  sudo -u ubuntu bash -c '
    export NVM_DIR="$HOME/.nvm"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    source "$NVM_DIR/nvm.sh"
    nvm install 20
    nvm use 20
    nvm alias default 20
  '
fi
# Agregar NVM al profile global
cat >> /etc/profile.d/nvm.sh << 'EOF'
export NVM_DIR="/home/ubuntu/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
success "Node configurado"

# ─── 5. Instalar OpenClaw globalmente ────────────────────────────────────────
info "Instalando OpenClaw CLI..."
sudo -u ubuntu bash -c '
  export NVM_DIR="$HOME/.nvm"
  source "$NVM_DIR/nvm.sh"
  npm install -g @openclaw/cli 2>/dev/null || npm install -g openclaw 2>/dev/null || true
'
success "OpenClaw instalado"

# ─── 6. Crear estructura de directorios ──────────────────────────────────────
info "Creando estructura de directorios..."
mkdir -p "$LOG_DIR"
mkdir -p "$SNAP_DIR"
mkdir -p "$PROJECT_DIR/openclaw/agents/"{alex,ivy,rose,salo,jeanette,ads-fb,ads-gumtree,script-runner}
mkdir -p "$PROJECT_DIR/supabase/"{migrations,functions/sync-to-sheets,functions/webhook-receiver}
mkdir -p "$PROJECT_DIR/"{pipelines,shared,docs,google-sheets,setup}

# Log rotation
cat > /etc/logrotate.d/rentinlondon << 'EOF'
/var/log/rentinlondon/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 ubuntu ubuntu
}
EOF

chown -R ubuntu:ubuntu "$PROJECT_DIR" "$LOG_DIR" 2>/dev/null || true
success "Directorios creados en $PROJECT_DIR"

# ─── 7. Crear archivo de log inicial ─────────────────────────────────────────
touch "$LOG_DIR/agent.log"
chown ubuntu:ubuntu "$LOG_DIR/agent.log"

success "=== Fase 1 completa ==="
echo ""
echo "Verificación:"
echo "  node: $(sudo -u ubuntu bash -c 'source /home/ubuntu/.nvm/nvm.sh && node --version' 2>/dev/null || echo 'ver con: source ~/.nvm/nvm.sh && node --version')"
echo "  docker: $(docker --version)"
echo "  timezone: $(timedatectl | grep 'Time zone' | awk '{print $3}')"
echo "  log dir: $LOG_DIR"
echo "  project dir: $PROJECT_DIR"
echo ""
echo "Siguiente paso: bash setup/02-supabase-setup.sh"
