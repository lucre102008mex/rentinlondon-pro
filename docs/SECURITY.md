# SECURITY.md — Guía de Seguridad
## RentInLondon PRO

## Resumen de Capas de Seguridad

```
┌─────────────────────────────────────────────────────────────┐
│                    CAPAS DE SEGURIDAD                        │
│                                                              │
│  Capa 1: RED                                                 │
│    UFW → Solo SSH + Tailscale                               │
│    fail2ban → Protección SSH brute force                    │
│    Tailscale VPN → Acceso administrativo seguro             │
│                                                              │
│  Capa 2: TRANSPORTE                                          │
│    HTTPS/TLS → Todo el tráfico hacia Supabase               │
│    HMAC SHA-256 → Todos los webhooks entrantes              │
│    JWT RS256 → Edge Functions → Google Sheets               │
│                                                              │
│  Capa 3: APLICACIÓN                                          │
│    OpenClaw → Agentes con permisos específicos              │
│    Mínimo privilegio → Cada agente con su propio DB role    │
│    identity_lock → SOUL.md e IDENTITY.md en chmod 444       │
│                                                              │
│  Capa 4: BASE DE DATOS                                       │
│    Row Level Security → Políticas por agente                │
│    service_role → Solo en Edge Functions                    │
│    Auditoría → agent_logs + compliance_audit (inmutables)   │
│                                                              │
│  Capa 5: ARCHIVOS                                            │
│    .env → chmod 600 (solo el propietario lee/escribe)       │
│    SOUL/IDENTITY → chmod 444 (solo lectura)                 │
│    Logs → Solo ubuntu:ubuntu                                │
└─────────────────────────────────────────────────────────────┘
```

---

## Gestión de Claves y Secretos

### Variables de Entorno

| Variable | Dónde se usa | Nivel de acceso | Generar con |
|----------|-------------|-----------------|-------------|
| `SUPABASE_ANON_KEY` | Agentes (lectura pública) | Bajo | Supabase Dashboard |
| `SUPABASE_SERVICE_ROLE_KEY` | Edge Functions únicamente | MÁXIMO | Supabase Dashboard |
| `WEBHOOK_HMAC_SECRET` | Todos los webhooks | Alto | `openssl rand -hex 32` |
| `GOOGLE_SA_PRIVATE_KEY` | sync-to-sheets Edge Fn | Alto | Google Cloud Console |
| `WHATSAPP_TOKEN` | N/A (se usa wacli/QR) | N/A | Sesión QR en OpenClaw |
| `TELEGRAM_BOT_TOKEN` | Alex únicamente | Alto | @BotFather en Telegram |

### Reglas de Manejo de Claves

1. **NUNCA** en el código fuente — solo en `.env` o Supabase Secrets
2. **NUNCA** en logs — usar `***` si se imprime
3. **NUNCA** en mensajes de git — verificar antes de commit
4. **Rotar cada 90 días** — especialmente HMAC_SECRET y tokens de API
5. **Mínimo privilegio** — cada .env solo tiene las claves que ese componente necesita

### Generar HMAC_SECRET
```bash
# Generar clave segura de 64 caracteres hex
openssl rand -hex 32

# Actualizar en .env y en Supabase Secrets
supabase secrets set WEBHOOK_HMAC_SECRET="$(openssl rand -hex 32)"
```

### Rotación de Claves de Supabase
```bash
# 1. Generar nueva service_role key en Supabase Dashboard
# 2. Actualizar Supabase Secrets
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="nueva_clave"
# 3. Actualizar supabase/.env
# 4. Reiniciar Edge Functions
supabase functions deploy sync-to-sheets
supabase functions deploy webhook-receiver
# 5. Reiniciar OpenClaw (si usa service_role)
sudo systemctl restart openclaw
```

---

## UFW (Uncomplicated Firewall)

### Configuración actual
```bash
# Ver reglas activas
sudo ufw status verbose

# Reglas configuradas por 03-security-hardening.sh:
# - DENY incoming (default)
# - ALLOW outgoing (default)
# - ALLOW ssh (port 22)
# - ALLOW in on tailscale0 (Tailscale VPN)
# - ALLOW in on tailscale0 to any port 3000 (OpenClaw, solo desde Tailscale)
# - ALLOW in on tailscale0 to any port 8080 (Dashboard, solo desde Tailscale)
```

### Si necesitas agregar una regla temporal
```bash
# Permitir temporalmente (diagnóstico)
sudo ufw allow 3000/tcp comment 'TEMPORAL — eliminar después'

# Eliminar la regla temporal
sudo ufw delete allow 3000/tcp
```

### IMPORTANTE: OpenClaw NO debe ser accesible por internet público
El gateway (puerto 3000) solo debe ser accesible a través de Tailscale o por el servidor localmente. Los webhooks de Meta y Google se configuran con URLs de Supabase Edge Functions, no directamente al servidor.

---

## fail2ban

### Estado y monitoreo
```bash
# Ver estado general
sudo fail2ban-client status

# Ver jail de SSH
sudo fail2ban-client status sshd

# Ver IPs baneadas
sudo fail2ban-client banned

# Ver logs de fail2ban
sudo tail -50 /var/log/fail2ban.log
```

### Desbanear una IP (si es legítima)
```bash
sudo fail2ban-client set sshd unbanip 1.2.3.4
```

---

## Tailscale

### Acceso administrativo seguro
Tailscale crea una VPN privada entre tu dispositivo personal y el servidor. Toda administración del servidor debe hacerse a través de Tailscale, nunca por SSH expuesto a internet.

```bash
# Ver estado de Tailscale
tailscale status

# Ver IP de Tailscale del servidor
tailscale ip -4

# Conectarse al servidor via Tailscale SSH
ssh ubuntu@[IP_TAILSCALE_DEL_SERVIDOR]
```

### Si Tailscale se desconecta
```bash
sudo systemctl restart tailscaled
sudo tailscale up --hostname rentinlondon-pro-server
```

---

## HMAC en Webhooks

### Cómo verificar manualmente
```bash
PAYLOAD='{"event":"test","source":"manual"}'
SECRET="TU_HMAC_SECRET"
SIG=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" -binary | xxd -p -c 256)
echo "Signature: sha256=$SIG"

# Enviar al webhook con firma
curl -X POST https://TU_PROYECTO.supabase.co/functions/v1/webhook-receiver \
  -H "Content-Type: application/json" \
  -H "X-Signature: sha256=$SIG" \
  -d "$PAYLOAD"
```

### Flujo de verificación HMAC
```
1. Cliente envía: POST + body + X-Signature: sha256=HASH
2. Edge Function recibe
3. Calcula HMAC-SHA256(body, secret)
4. Compara timing-safe con la firma recibida
5. Si no coincide → 401 Unauthorized (no procesa nada)
6. Si coincide → procesa el evento
```

---

## Row Level Security (RLS)

### Ver políticas activas
```sql
SELECT schemaname, tablename, policyname, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

### Verificar acceso de un agente
```sql
-- Simular acceso de Ivy
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"agent_id": "ivy"}';

-- Intentar leer leads
SELECT count(*) FROM leads;
-- Solo debe ver leads UK (es_internacional = FALSE)

RESET role;
RESET "request.jwt.claims";
```

### Roles de base de datos

| Agente | DB Role | Permisos |
|--------|---------|----------|
| Todos (lectura pública) | anon | zone_ranges (solo lectura) |
| Agentes | authenticated | Según políticas RLS |
| Edge Functions | service_role | Acceso completo |

---

## Auditoría y Monitoreo

### Detectar acceso inusual
```sql
-- Acciones inusuales en las últimas 24h
SELECT agente, accion, COUNT(*), MIN(created_at), MAX(created_at)
FROM agent_logs
WHERE created_at > NOW() - INTERVAL '24 hours'
  AND exito = FALSE
GROUP BY agente, accion
ORDER BY COUNT(*) DESC;

-- Intentos de acceso a datos fuera de permisos
SELECT * FROM agent_logs
WHERE metadata @> '{"access_denied": true}'
  AND created_at > NOW() - INTERVAL '7 days';
```

### Alertas de seguridad configuradas en cost-guard pipeline
- Tokens anómalos (> 200% del promedio para un agente)
- Requests fuera de horario (3 AM - 5 AM London)
- Errores de HMAC repetidos (posible intento de ataque)

---

## Checklist de Seguridad Mensual

- [ ] Rotar HMAC_SECRET y actualizar en todos los servicios
- [ ] Verificar que no hay puertos expuestos: `sudo ufw status`
- [ ] Revisar logs de fail2ban por IPs baneadas frecuentemente
- [ ] Revisar agent_logs por acciones fuera de patrón
- [ ] Verificar permisos de .env: `ls -la supabase/.env openclaw/.env`
- [ ] Verificar permisos de SOUL/IDENTITY: `ls -la openclaw/agents/*/`
- [ ] Revisar certificados de Tailscale (se renuevan automáticamente)
- [ ] Backup de la base de datos: `supabase db dump`
- [ ] Verificar que service_role key no está en logs: `grep -r "service_role" /var/log/`
