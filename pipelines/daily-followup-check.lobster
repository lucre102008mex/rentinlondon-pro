# Pipeline: Daily Follow-up Check
# Ejecuta cada día a las 9:00 AM Europe/London
# Revisa followups, tasks y nurturing pasos para el día

name: daily-followup-check
description: "Revisa followups, tasks y nurturing - alerta a agentes"
timezone: Europe/London
schedule: "0 9 * * 1-6"  # Lun-Sáb 9AM London

steps:
  # ─── 1. Followups para hoy ───────────────────────────────────────────────
  - id: check_followups_hoy
    name: "Verificar followups pendientes para hoy"
    agent: alex
    action: supabase_query
    params:
      view: v_followups_hoy
      limit: 50

  # ─── 2. Tasks para hoy ───────────────────────────────────────────────────
  - id: check_tasks_hoy
    name: "Verificar tasks pendientes para hoy"
    agent: alex
    action: supabase_query
    params:
      view: v_tasks_hoy
      limit: 50

  # ─── 3. Pasos de nurturing para hoy ─────────────────────────────────────
  - id: check_nurturing_hoy
    name: "Verificar secuencias de nurturing para hoy"
    agent: alex
    action: supabase_query
    params:
      table: lead_nurturing_sequences
      select: "id,lead_id,tipo_secuencia,paso_actual,total_pasos,proximo_paso_fecha"
      filter: "estado.eq.activa"
      order: "proximo_paso_fecha.asc"
      limit: 20
    on_results: process_nurturing

  # ─── 4. Enviar alertas a agentes con followups ──────────────────────────
  - id: alert_ivy_followups
    name: "Alertar a Ivy sobre followups de hoy"
    agent: alex
    action: conditional
    condition: "check_followups_hoy.results.filter(f => f.agente_asignado === 'ivy').length > 0"
    on_true:
      - action: telegram_send
        params:
          message: "🔔 FOLLOWUPS HOY - IVY\n\n{{check_followups_hoy.results.filter(f => f.agente_asignado === 'ivy').map(f => `• ${f.nombre} - ${f.zona_preferida} - SCL: ${f.scl_score} - Mudanza: ${f.fecha_mudanza}`).join('\n')}}"
          chat_id: "${TELEGRAM_CHAT_ID}"

  - id: alert_rose_followups
    name: "Alertar a Rose sobre followups de hoy"
    agent: alex
    action: conditional
    condition: "check_followups_hoy.results.filter(f => f.agente_asignado === 'rose').length > 0"
    on_true:
      - action: telegram_send
        params:
          message: "🔔 FOLLOWUPS HOY - ROSE\n\n{{check_followups_hoy.results.filter(f => f.agente_asignado === 'rose').map(f => `• ${f.nombre} - ${f.zona_preferida} - SCL: ${f.scl_score}`).join('\n')}}"
          chat_id: "${TELEGRAM_CHAT_ID}"

  - id: alert_salo_followups
    name: "Alertar a Salo sobre followups de hoy"
    agent: alex
    action: conditional
    condition: "check_followups_hoy.results.filter(f => f.agente_asignado === 'salo').length > 0"
    on_true:
      - action: telegram_send
        params:
          message: "🔔 FOLLOWUPS HOY - SALO\n\n{{check_followups_hoy.results.filter(f => f.agente_asignado === 'salo').map(f => `• ${f.nombre} - ${f.zona_preferida} - SCL: ${f.scl_score}`).join('\n')}}"
          chat_id: "${TELEGRAM_CHAT_ID}"

  - id: alert_jeanette_followups
    name: "Alertar a Jeanette sobre followups de hoy"
    agent: alex
    action: conditional
    condition: "check_followups_hoy.results.filter(f => f.agente_asignado === 'jeanette').length > 0"
    on_true:
      - action: telegram_send
        params:
          message: "🔔 FOLLOWUPS HOY - JEANETTE\n\n{{check_followups_hoy.results.filter(f => f.agente_asignado === 'jeanette').map(f => `• ${f.nombre} - ${f.zona_preferida} - SCL: ${f.scl_score}`).join('\n')}}"
          chat_id: "${TELEGRAM_CHAT_ID}"

  # ─── 5. Generar resumen diario de operaciones ───────────────────────────
  - id: generate_ops_summary
    name: "Generar resumen de operaciones del día"
    agent: alex
    action: generate_markdown
    template: |
      ## 📊 RESUMEN DE OPERACIONES - {{date}}

      ### Followups Pendientes
      | Agente | Cantidad |
      |--------|----------|
      | Ivy | {{check_followups_hoy.results.filter(f => f.agente_asignado === 'ivy').length}} |
      | Rose | {{check_followups_hoy.results.filter(f => f.agente_asignado === 'rose').length}} |
      | Salo | {{check_followups_hoy.results.filter(f => f.agente_asignado === 'salo').length}} |
      | Jeanette | {{check_followups_hoy.results.filter(f => f.agente_asignado === 'jeanette').length}} |

      ### Tasks Pendientes
      | Agente | Cantidad |
      |--------|----------|
      | Ivy | {{check_tasks_hoy.results.filter(t => t.agente_asignado === 'ivy').length}} |
      | Rose | {{check_tasks_hoy.results.filter(t => t.agente_asignado === 'rose').length}} |
      | Salo | {{check_tasks_hoy.results.filter(t => t.agente_asignado === 'salo').length}} |
      | Jeanette | {{check_tasks_hoy.results.filter(t => t.agente_asignado === 'jeanette').length}} |

      ### Nurturing Activo
      - Secuencias activas: {{check_nurturing_hoy.results.length}}
      - Para hoy: {{check_nurturing_hoy.results.filter(n => n.proximo_paso_fecha === today).length}}

  # ─── 6. Enviar resumen al dueño ─────────────────────────────────────────
  - id: send_summary_to_owner
    name: "Enviar resumen al dueño"
    agent: alex
    action: telegram_send
    depends_on:
      - generate_ops_summary
    params:
      message: "{{generate_ops_summary.output}}"
      chat_id: "${TELEGRAM_CHAT_ID}"
      parse_mode: "Markdown"

  # ─── 7. Log de ejecución ─────────────────────────────────────────────────
  - id: log_completion
    name: "Registrar ejecución en agent_logs"
    agent: alex
    action: log_action
    always_run: true
    params:
      accion: "daily_followup_check_completed"
      exito: "${pipeline.success}"
      metadata:
        followups_hoy: "${check_followups_hoy.results.length}"
        tasks_hoy: "${check_tasks_hoy.results.length}"
        nurturing_hoy: "${check_nurturing_hoy.results.length}"

# Error handling
on_error:
  - action: telegram_send
    params:
      message: "⚠️ Error en daily-followup-check: ${error.message}"
      chat_id: "${TELEGRAM_CHAT_ID}"