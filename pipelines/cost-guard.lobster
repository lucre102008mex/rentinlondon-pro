# Pipeline: Cost Guard
# Ejecuta todos los días a las 10:00 PM Europe/London
# Monitorea consumo de tokens y costos por agente

name: cost-guard
description: "Monitoreo diario de consumo de tokens y costos por agente — alerta si supera umbrales"
timezone: Europe/London
schedule: "0 22 * * *"

steps:
  - id: query_token_usage_today
    name: "Consultar tokens usados hoy por agente"
    agent: alex
    action: supabase_query
    params:
      table: agent_logs
      filter: "created_at.gte.today_london_start"
      select: "agente,sum(tokens_usados) as total_tokens,count(*) as total_requests,avg(latencia_ms) as avg_latency"
      group_by: "agente"

  - id: query_token_usage_week
    name: "Consultar tokens usados esta semana"
    agent: alex
    action: supabase_query
    params:
      table: agent_logs
      filter: "created_at.gte.week_start_london"
      select: "agente,sum(tokens_usados) as week_tokens"
      group_by: "agente"

  - id: calculate_costs
    name: "Calcular costos estimados en GBP"
    agent: alex
    action: calculate_ai_costs
    depends_on:
      - query_token_usage_today
    params:
      currency: GBP
      cost_per_1k_tokens: "${COST_PER_1K_TOKENS:-0.002}"

  - id: check_limits
    name: "Verificar si algún agente superó límites"
    agent: alex
    action: check_thresholds
    depends_on:
      - query_token_usage_today
      - calculate_costs
    params:
      thresholds:
        - agent: alex
          daily_token_limit: 20000
          daily_cost_limit_gbp: 5
        - agent: ivy
          daily_token_limit: 30000
          daily_cost_limit_gbp: 7
        - agent: rose
          daily_token_limit: 25000
          daily_cost_limit_gbp: 6
        - agent: salo
          daily_token_limit: 20000
          daily_cost_limit_gbp: 5
        - agent: jeanette
          daily_token_limit: 40000
          daily_cost_limit_gbp: 10
        - agent: ads-fb
          daily_token_limit: 10000
          daily_cost_limit_gbp: 2.5
        - agent: ads-gumtree
          daily_token_limit: 8000
          daily_cost_limit_gbp: 2
        - agent: script-runner
          daily_token_limit: 15000
          daily_cost_limit_gbp: 3.5
      global_daily_limit: 100000
      global_daily_cost_gbp: 50

  - id: generate_cost_report
    name: "Generar reporte de costos"
    agent: alex
    action: generate_cost_report
    depends_on:
      - query_token_usage_today
      - query_token_usage_week
      - calculate_costs
      - check_limits
    params:
      format: telegram_markdown

  - id: send_cost_report
    name: "Enviar reporte de costos al dueño"
    agent: alex
    action: telegram_send
    depends_on:
      - generate_cost_report
    params:
      chat_id: "${TELEGRAM_CHAT_ID}"
      message: |
        💰 **Cost Guard — Reporte de Tokens ${date_london}**

        ${cost_report.summary}

        **Por agente (hoy)**:
        ${cost_report.by_agent_table}

        **Total semana**: ${cost_report.week_total_tokens} tokens | £${cost_report.week_total_cost}

        ${cost_report.alerts_section}

  - id: alert_if_exceeded
    name: "Alerta urgente si se superaron límites globales"
    agent: alex
    action: conditional_telegram_send
    depends_on:
      - check_limits
    params:
      condition: "${check_limits.global_exceeded}"
      message: |
        🚨 **ALERTA CRÍTICA — Límite de Costos Superado**

        Se superó el límite diario global de tokens/costo.

        Agentes afectados: ${check_limits.exceeded_agents}
        Tokens usados: ${check_limits.total_tokens} / ${global_daily_limit}
        Costo estimado: £${check_limits.total_cost} / £${global_daily_cost_gbp}

        **Acción recomendada**: Revisar agentes con mayor consumo
        Para pausar un agente: `/pausar [nombre_agente]`

  - id: pause_exceeded_agents
    name: "Pausar agentes que superaron su límite individual (opcional)"
    agent: alex
    action: pause_agents_if_exceeded
    depends_on:
      - check_limits
    params:
      auto_pause: false
      notify_before_pause: true
      note: "Auto-pausa deshabilitada por defecto — habilitar con auto_pause: true"

  - id: log_cost_check
    name: "Registrar verificación de costos"
    agent: alex
    action: log_action
    always_run: true
    params:
      accion: "cost_guard_completed"
      metadata:
        total_tokens_today: "${query_token_usage_today.grand_total}"
        total_cost_today_gbp: "${calculate_costs.total_gbp}"
        limits_exceeded: "${check_limits.any_exceeded}"
        agents_over_limit: "${check_limits.exceeded_agents}"

on_error:
  - action: telegram_send
    params:
      message: "⚠️ Error en cost-guard pipeline: ${error.message}"
      chat_id: "${TELEGRAM_CHAT_ID}"
