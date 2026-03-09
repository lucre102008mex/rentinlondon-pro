#!/usr/bin/env bash
# =============================================================================
# RentInLondon PRO — Fase 3: Hardening de seguridad del servidor
# =============================================================================
set -euo pipefail

YELLOW='\033[1;33m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${YELLOW}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && error "Ejecutar como root: sudo bash $0"

PROJECT_DIR="/home/ubuntu/rentinlondon-pro"

# ─── 1. Instalar UFW y fail2ban ───────────────────────────────────────────────
info "Instalando UFW y fail2ban..."
apt-get update -y
apt-get install -y ufw fail2ban
success "UFW y fail2ban instalados"

# ─── 2. Configurar UFW ───────────────────────────────────────────────────────
info "Configurando UFW..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# SSH
ufw allow ssh comment 'SSH access'

# Tailscale (interfaz de red VPN)
ufw allow in on tailscale0 comment 'Tailscale VPN'

# Solo permitir tráfico interno desde Tailscale en puertos de OpenClaw
ufw allow in on tailscale0 to any port 3000 comment 'OpenClaw Gateway (Tailscale only)'
ufw allow in on tailscale0 to any port 8080 comment 'Dashboard (Tailscale only)'

# Habilitar UFW
echo "y" | ufw enable
success "UFW configurado"
ufw status verbose

# ─── 3. Configurar fail2ban para SSH ─────────────────────────────────────────
info "Configurando fail2ban para SSH..."
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
backend  = auto
usedns   = warn
logencoding = auto
enabled = false

[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 5
bantime  = 86400
findtime = 600
action   = %(action_mwl)s

[sshd-ddos]
enabled  = true
port     = ssh
filter   = sshd-ddos
logpath  = /var/log/auth.log
maxretry = 10
bantime  = 3600

[recidive]
enabled  = true
filter   = recidive
logpath  = /var/log/fail2ban.log
action   = %(action_mwl)s
bantime  = 604800
findtime = 86400
maxretry = 5
EOF

systemctl enable fail2ban
systemctl restart fail2ban
success "fail2ban configurado y activo"

# ─── 4. Permisos de archivos .env ────────────────────────────────────────────
info "Aplicando permisos seguros a archivos .env..."
for env_file in \
  "$PROJECT_DIR/supabase/.env" \
  "$PROJECT_DIR/openclaw/.env"; do
  if [[ -f "$env_file" ]]; then
    chmod 600 "$env_file"
    chown ubuntu:ubuntu "$env_file"
    success "chmod 600: $env_file"
  else
    info "No existe aún (crear antes del deploy): $env_file"
  fi
done

# ─── 5. Permisos de logs ──────────────────────────────────────────────────────
chmod 750 /var/log/rentinlondon 2>/dev/null || true
chown ubuntu:ubuntu /var/log/rentinlondon 2>/dev/null || true

# ─── 6. Configurar SSH hardening ─────────────────────────────────────────────
info "Aplicando hardening SSH..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Asegurar configuración segura de SSH
cat >> /etc/ssh/sshd_config << 'EOF'

# RentInLondon PRO — SSH Hardening
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowAgentForwarding no
X11Forwarding no
EOF

systemctl reload sshd || (sshd -t && systemctl reload ssh)
success "SSH hardening aplicado"

# ─── 7. Configurar sysctl para seguridad de red ───────────────────────────────
info "Configurando parámetros de red seguros..."
cat > /etc/sysctl.d/99-rentinlondon-security.conf << 'EOF'
# RentInLondon PRO — Network Security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.conf.all.log_martians = 1
EOF
sysctl -p /etc/sysctl.d/99-rentinlondon-security.conf
success "Parámetros de red aplicados"

success "=== Fase 3 completa ==="
echo ""
echo "Estado del sistema:"
echo "  UFW: $(ufw status | head -1)"
echo "  fail2ban: $(fail2ban-client status | head -3 | tail -1)"
echo ""
echo "Siguiente paso: sudo bash setup/04-tailscale-setup.sh"
