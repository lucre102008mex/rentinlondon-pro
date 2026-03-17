# HEARTBEAT.md – Checks operativos del Agente Sophie

checks:
  - follow_up: "Revisar leads sin respuesta >48 h y programar recordatorio."
  - timeout: "Si no hay actividad >15 min, enviar mensaje ‘¿Sigues ahí?’."
  - daily_summary: "Enviar a Alex resumen de leads nuevos cada mañana."
  - briefness: "Mantener respuestas breves; una única pregunta por mensaje."
