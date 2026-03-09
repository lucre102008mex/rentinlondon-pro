# Log del Sistema — RentInLondon PRO

> Log de eventos importantes del sistema. Para logs detallados, ver tabla `agent_logs` en Supabase.

## Formato de entrada de log

```
[YYYY-MM-DD HH:MM Europe/London] [AGENTE] [NIVEL] Descripción del evento
```

## Niveles de log

- `INFO` — Operación normal
- `WARN` — Situación que requiere atención
- `ERROR` — Error que impidió una acción
- `ALERT` — Alerta de negocio (limit, compliance, urgencia)
- `COMPLIANCE` — Evento relacionado con UK Equality Act 2010

## Log de Eventos

```
[Sistema iniciado — aguardando primeros eventos]
```

---

## Acceder al log completo

```bash
# Ver log en tiempo real
tail -f /var/log/rentinlondon/agent.log

# Ver últimas 100 líneas
tail -100 /var/log/rentinlondon/agent.log

# Filtrar por agente
grep "ALEX" /var/log/rentinlondon/agent.log

# Ver solo errores
grep "ERROR\|ALERT" /var/log/rentinlondon/agent.log

# En Supabase (SQL)
SELECT * FROM agent_logs 
WHERE created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC
LIMIT 100;
```

---
*Este archivo es para referencia manual. El log real está en /var/log/rentinlondon/ y en Supabase.*
