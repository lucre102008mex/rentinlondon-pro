#!/usr/bin/env bash
# =============================================================================
# RentInLondon PRO — Bloqueo de archivos de identidad de agentes
# Hace chmod 444 a TODOS los SOUL.md e IDENTITY.md de los 8 agentes
# =============================================================================
set -euo pipefail

YELLOW='\033[1;33m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${YELLOW}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# Detectar directorio del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
AGENTS_DIR="$PROJECT_DIR/openclaw/agents"

info "Buscando archivos SOUL.md e IDENTITY.md en $AGENTS_DIR..."

if [[ ! -d "$AGENTS_DIR" ]]; then
  error "Directorio de agentes no encontrado: $AGENTS_DIR"
fi

LOCKED=0
FAILED=0

# Agentes esperados
AGENTS=("alex" "ivy" "rose" "salo" "jeanette" "ads-fb" "ads-gumtree" "script-runner")

for agent in "${AGENTS[@]}"; do
  AGENT_DIR="$AGENTS_DIR/$agent"
  
  if [[ ! -d "$AGENT_DIR" ]]; then
    echo -e "  ${RED}✗${NC} Directorio no encontrado: $AGENT_DIR"
    ((FAILED++)) || true
    continue
  fi
  
  for pattern in "*-soul.md" "*-identity.md" "SOUL.md" "IDENTITY.md"; do
    for file in "$AGENT_DIR"/$pattern; do
      if [[ -f "$file" ]]; then
        chmod 444 "$file"
        echo -e "  ${GREEN}✓${NC} Bloqueado (444): $file"
        ((LOCKED++)) || true
      fi
    done
  done
done

echo ""
info "Verificando permisos..."
find "$AGENTS_DIR" \( -iname "*soul.md" -o -iname "*identity.md" \) -exec ls -la {} \;

echo ""
success "=== Bloqueo de identidades completo ==="
echo "  Archivos bloqueados: $LOCKED"
echo "  Errores: $FAILED"
echo ""
if [[ $FAILED -gt 0 ]]; then
  echo -e "${RED}ADVERTENCIA${NC}: $FAILED directorios de agentes no encontrados."
  echo "  Asegúrate de que los agentes estén correctamente instalados."
fi
echo ""
echo "Para desbloquear temporalmente (con sudo):"
echo "  sudo chmod 644 openclaw/agents/AGENTE/ARCHIVO.md"
echo "  # Hacer cambios"
echo "  bash setup/identity_lock.sh  # Re-bloquear"
