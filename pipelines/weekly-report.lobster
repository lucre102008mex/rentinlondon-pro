# Pipeline: Weekly Report
# Ejecuta todos los lunes a las 9:00 AM Europe/London
# Coordinado por Alex — análisis semanal completo

name: weekly-report
description: "Reporte semanal comparativo con métricas de rendimiento y ROI"
timezone: Europe/London
schedule: "0 9 * * 1"

steps:
  - id: define_period
    name: "Definir período de la semana anterior"
    agent: alex
    action: calculate_date_range
    params:
      period: last_week
      timezone: "Europe/London"

  - id: query_weekly_leads
    name: "Métricas de leads de la semana"
    agent: alex
    action: supabase_query
    params:
      table: leads
      select: "canal_origen,status,urgency_score,budget_fit,es_internacional,asignado_a,count(*)"
      filter: "created_at.gte.${period.start}.lte.${period.end}"
      group_by: "canal_origen,status,urgency_score,budget_fit,es_internacional,asignado_a"

  - id: query_weekly_viewings
    name: "Viewings de la semana"
    agent: alex
    action: supabase_query
    params:
      table: viewings
      filter: "fecha_hora.gte.${period.start}.lte.${period.end}"
      select: "estado,agente,tipo,count(*)"
      group_by: "estado,agente,tipo"

  - id: query_weekly_contracts
    name: "Contratos firmados en la semana"
    agent: alex
    action: supabase_query
    params:
      table: contracts
      filter: "created_at.gte.${period.start}.lte.${period.end}"
      select: "estado,agente_cierre,precio_mensual,comision_agencia"

  - id: query_ads_performance
    name: "Rendimiento de ads (FB + Gumtree)"
    agent: alex
    action: supabase_query
    params:
      table: agent_logs
      filter: "agente.in.(ads-fb,ads-gumtree).created_at.gte.${period.start}.lte.${period.end}"
      select: "agente,sum(tokens_usados),count(*)"
      group_by: "agente"

  - id: query_agent_activity
    name: "Actividad por agente"
    agent: alex
    action: supabase_query
    params:
      table: agent_logs
      filter: "created_at.gte.${period.start}.lte.${period.end}"
      select: "agente,sum(tokens_usados),count(*),avg(latencia_ms)"
      group_by: "agente"

  - id: query_previous_week
    name: "Métricas de semana anterior (para comparativa)"
    agent: alex
    action: supabase_query
    params:
      table: weekly_summaries
      filter: "semana_inicio.eq.${period.previous_start}"
      limit: 1

  - id: query_weekly_compliance
    name: "Auditoría de compliance de la semana"
    agent: alex
    action: supabase_query
    params:
      view: v_compliance_report
      filter: "created_at_london.gte.${period.start}.lte.${period.end}"

  - id: generate_weekly_report
    name: "Generar reporte semanal completo"
    agent: alex
    action: generate_weekly_report
    depends_on:
      - query_weekly_leads
      - query_weekly_viewings
      - query_weekly_contracts
      - query_ads_performance
      - query_agent_activity
      - query_previous_week
      - query_weekly_compliance
    params:
      include_comparison: true
      include_roi: true
      include_recommendations: true
      timezone: "Europe/London"

  - id: send_weekly_report
    name: "Enviar reporte semanal vía Telegram"
    agent: alex
    action: telegram_send
    depends_on:
      - generate_weekly_report
    params:
      chat_id: "${TELEGRAM_CHAT_ID}"
      parse_mode: "Markdown"
      split_long_messages: true

  - id: save_weekly_summary
    name: "Guardar resumen en weekly_summaries"
    agent: alex
    action: supabase_insert
    depends_on:
      - generate_weekly_report
    params:
      table: weekly_summaries
      data: "${weekly_report.summary_data}"

  - id: sync_to_sheets
    name: "Sincronizar weekly_summaries a Google Sheets"
    agent: alex
    action: trigger_edge_function
    depends_on:
      - save_weekly_summary
    params:
      function: sync-to-sheets
      payload:
        table: weekly_summaries

on_error:
  - action: telegram_send
    params:
      message: "⚠️ Error en weekly-report pipeline: ${error.message}"
      chat_id: "${TELEGRAM_CHAT_ID}"
