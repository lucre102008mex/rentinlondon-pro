# Pipeline: Daily Report
# Ejecuta lunes a viernes a las 8:00 AM Europe/London
# Coordinado por Alex — entregado al dueño vía Telegram

name: daily-report
description: "Reporte diario de métricas del sistema — Alex vía Telegram"
timezone: Europe/London
schedule: "0 8 * * 1-5"

steps:
  - id: load_context
    name: "Cargar snapshot de contexto"
    agent: alex
    action: load_snapshot
    params:
      path: "shared/snapshots/"
      max_age_hours: 6
    on_stale:
      action: regenerate_snapshot
      script: "setup/context_loader.sh"

  - id: query_daily_summary
    name: "Consultar resumen diario de Supabase"
    agent: alex
    action: supabase_query
    params:
      view: v_daily_summary
      timezone: "Europe/London"

  - id: query_hot_leads
    name: "Obtener leads HOT sin contacto reciente"
    agent: alex
    action: supabase_query
    params:
      view: v_leads_activos
      filter: "scl_score.gte.7"
      order: "scl_score.desc,ultima_interaccion.asc"
      limit: 10

  - id: query_dss_leads
    name: "Obtener leads DSS/UC con match disponible"
    agent: alex
    action: supabase_query
    params:
      view: v_leads_dss_pendientes
      filter: "tiene_match_inmediato.eq.true"
      order: "scl_score.desc"
      limit: 10
    alert_if_results: true
    alert_message: "🏠 ALERTA DSS: {count} lead(s) DSS/UC tienen propiedad compatible disponible — contactar INMEDIATO"

  - id: query_void_properties
    name: "Obtener propiedades void"
    agent: alex
    action: supabase_query
    params:
      view: v_propiedades_void
      order: "dias_void.desc"
      limit: 10

  - id: query_dormant_leads
    name: "Obtener leads dormantes"
    agent: alex
    action: supabase_query
    params:
      view: v_leads_dormantes
      order: "dias_sin_contacto.desc"
      limit: 10

  - id: query_token_usage
    name: "Obtener uso de tokens del día"
    agent: alex
    action: supabase_query
    params:
      table: agent_logs
      select: "agente,sum(tokens_usados)"
      filter: "created_at.gte.today_london"
      group_by: "agente"

  - id: query_compliance
    name: "Verificar flags de compliance del día"
    agent: alex
    action: supabase_query
    params:
      table: compliance_audit
      filter: "created_at.gte.today_london"
      select: "count(*)"

  - id: generate_report
    name: "Generar reporte formateado"
    agent: alex
    action: generate_daily_report
    depends_on:
      - query_daily_summary
      - query_hot_leads
      - query_dss_leads
      - query_void_properties
      - query_dormant_leads
      - query_token_usage
      - query_compliance
    output:
      format: telegram_markdown
      template: "templates/daily_report.md"

  - id: send_report
    name: "Enviar reporte a dueño vía Telegram"
    agent: alex
    action: telegram_send
    depends_on:
      - generate_report
    params:
      chat_id: "${TELEGRAM_CHAT_ID}"
      parse_mode: "Markdown"

  - id: store_summary
    name: "Guardar resumen en weekly_summaries (acumulado)"
    agent: alex
    action: supabase_upsert
    depends_on:
      - generate_report
    params:
      table: weekly_summaries
      upsert_key: semana_inicio

  - id: log_completion
    name: "Registrar ejecución en agent_logs"
    agent: alex
    action: log_action
    always_run: true
    params:
      accion: "daily_report_completed"
      exito: "${pipeline.success}"

on_error:
  - action: telegram_send
    params:
      message: "⚠️ Error en daily-report pipeline: ${error.message}"
      chat_id: "${TELEGRAM_CHAT_ID}"
