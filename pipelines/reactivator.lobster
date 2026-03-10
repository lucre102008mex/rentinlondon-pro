# =============================================================================
# Pipeline: Reactivator (Sub-agente bajo control de Alex)
# Motor de reactivación de leads dormidos
# Adaptado del reactivator.py v5.1 — Anti-Robot / Cooldown Extendido
#
# CRON: Arranca automáticamente a las 7:00 AM Europe/London
# Trabaja de 7:00 AM a 5:00 PM London (L-V), Sáb 9-17, Dom 10-15
# Alex tiene control total: iniciar, detener, pausar, reanudar
# Script-Runner ejecuta y reporta TODO a Alex
# =============================================================================

name: reactivator
description: "Sub-agente de reactivación bajo control de Alex — protecciones anti-bot y horario humano 7-17 London"
timezone: Europe/London
schedule: "0 7 * * * Europe/London"

# ─── Control de Alex (comandos Telegram) ─────────────────────────────────────
# Alex puede controlar el reactivator en cualquier momento:
#   /reactivar           → Inicia manualmente fuera de horario CRON
#   /parar_reactivador   → Detiene inmediatamente la sesión actual
#   /pausar_reactivador  → Pausa temporalmente (reanuda con /reanudar)
#   /reanudar_reactivador → Reanuda tras pausa
#   /estado_reactivador  → Muestra estado actual, enviados hoy, límite
controlled_by: alex
commands:
  start: "/reactivar"
  stop: "/parar_reactivador"
  pause: "/pausar_reactivador"
  resume: "/reanudar_reactivador"
  status: "/estado_reactivador"

# =============================================================================
# SAFETY: Protecciones anti-detección de bot (INVIOLABLES)
# Replicado del reactivator.py v5.1
# =============================================================================
safety:

  # ─── Horario laboral humano (Europe/London) ──────────────────────────────────
  # FUERA de estas ventanas NO envía NADA — se detiene automáticamente
  working_hours:
    monday_to_friday:
      start: "07:00"
      end: "17:00"
    saturday:
      start: "09:00"
      end: "17:00"
    sunday:
      start: "10:00"
      end: "15:00"
    timezone: Europe/London
    enforce: strict

  # ─── Cooldown entre mensajes ─────────────────────────────────────────────────
  # Después de cada envío, espera entre 22:50 y 42:33 minutos
  cooldown_between_messages:
    min_seconds: 1370   # 22 minutos 50 segundos
    max_seconds: 2553   # 42 minutos 33 segundos

  # ─── Drift de inicio (anti-patrón) ──────────────────────────────────────────
  # Antes de procesar cada lead, espera 30-300 segundos aleatorios
  pre_action_drift:
    min_seconds: 30
    max_seconds: 300

  # ─── Límite diario aleatorio ────────────────────────────────────────────────
  daily_limit:
    min: 10
    max: 18
    persist_key: "reactivator_daily_limit"

  # ─── Máximo intentos por lead ───────────────────────────────────────────────
  max_attempts_per_lead: 5

  # ─── Cooldown por lead ──────────────────────────────────────────────────────
  cooldown_days_per_lead: 7

# =============================================================================
# MESSAGE POOL: Rotación de mensajes (anti-repetición)
# Trackea últimos 4 enviados para no repetir
# =============================================================================
message_pool:
  rotation_memory: 4
  persist_key: "reactivator_msg_history"
  templates:
    - "Hi {first_name}, Jeanette here — quick question: still looking for a room in London?"
    - "Hey {first_name}, it's Jeanette from RentInLondon. Are you still searching for a place?"
    - "Hi {first_name}, just checking in — are you still looking for accommodation in London?"
    - "Hello {first_name}, Jeanette here. We have some new rooms available — still interested?"
    - "Hi {first_name}, hope you're well! Any update on your room search in London?"
    - "Hey {first_name}, Jeanette from RentInLondon checking in. Still need a place?"
    - "Hi {first_name}, we've got fresh listings this week — shall I send you some options?"
    - "Hello {first_name}, just wanted to check if you're still looking for somewhere to live in London?"
    - "Hi {first_name}, it's been a little while — are you still in the market for a room?"
    - "Hey {first_name}, Jeanette here. Some great rooms just came up — still searching?"

# =============================================================================
# NAME CLEANING: Sanitización de nombres
# =============================================================================
name_cleaning:
  fallback: "there"
  min_length: 3
  blocked_patterns:
    - "\\d+"
    - "lead"
    - "wa"
    - "unknown"
    - "client"
    - "prospect"
  transform: first_word_titlecase

# =============================================================================
# STEPS
# =============================================================================
steps:

  # ─── PASO 1: Log interno de arranque (sin molestar a Alex) ────────────────
  - id: log_start
    name: "Registrar inicio de sesión"
    agent: script-runner
    action: log_action
    params:
      accion: "reactivator_started"
      metadata:
        session_start: "${now}"

  # ─── PASO 2: Verificar horario laboral ─────────────────────────────────────
  - id: check_working_hours
    name: "Verificar que estamos en horario laboral London (7-17)"
    agent: script-runner
    action: check_working_hours
    depends_on:
      - notify_alex_start
    params:
      rules: "${safety.working_hours}"
      on_outside_hours: stop_pipeline
      on_outside_hours_log: "Fuera de horario laboral London — reactivator detenido"

  # ─── PASO 3: Verificar si Alex pausó el reactivator ───────────────────────
  - id: check_alex_control
    name: "Verificar si Alex pausó o detuvo el reactivator"
    agent: script-runner
    action: check_control_state
    depends_on:
      - check_working_hours
    params:
      controlled_by: alex
      on_paused: wait_for_resume
      on_stopped: stop_pipeline
      on_stopped_log: "Reactivator detenido por orden de Alex"

  # ─── PASO 4: Obtener límite diario ────────────────────────────────────────
  - id: get_daily_limit
    name: "Obtener o generar límite diario aleatorio (10-30)"
    agent: script-runner
    action: get_or_generate_daily_limit
    depends_on:
      - check_alex_control
    params:
      min: "${safety.daily_limit.min}"
      max: "${safety.daily_limit.max}"
      persist_key: "${safety.daily_limit.persist_key}"

  # ─── PASO 5: Contar enviados hoy ──────────────────────────────────────────
  - id: count_sent_today
    name: "Contar reactivaciones enviadas hoy"
    agent: script-runner
    action: supabase_query
    depends_on:
      - get_daily_limit
    params:
      table: agent_logs
      filter: "accion.eq.reactivation_sent,created_at.gte.today_london_start"
      select: "count"

  # ─── PASO 6: Verificar límite diario ──────────────────────────────────────
  - id: check_daily_limit
    name: "Verificar si se alcanzó el límite diario"
    agent: script-runner
    action: check_threshold
    depends_on:
      - count_sent_today
      - get_daily_limit
    params:
      current: "${count_sent_today.count}"
      limit: "${get_daily_limit.limit}"
      on_exceeded: stop_pipeline
      on_exceeded_log: "Límite diario alcanzado (${count_sent_today.count}/${get_daily_limit.limit})"

  # ─── PASO 7: Consultar leads dormidos elegibles ───────────────────────────
  - id: query_eligible
    name: "Obtener leads dormidos elegibles"
    agent: script-runner
    action: supabase_query
    depends_on:
      - check_daily_limit
    params:
      view: v_leads_dormantes
      filter: "dias_sin_contacto.gte.${safety.cooldown_days_per_lead}"
      order: "dias_sin_contacto.desc,scl_score.desc"
      limit: 50

  # ─── PASO 8: Filtrar por max intentos ─────────────────────────────────────
  - id: filter_max_attempts
    name: "Excluir leads con 5+ intentos de reactivación"
    agent: script-runner
    action: filter_reactivation_count
    depends_on:
      - query_eligible
    params:
      source: query_eligible
      max_attempts: "${safety.max_attempts_per_lead}"
      count_field: "metadata->reactivation_count"

  # ─── PASO 9: Anti-amnesia ─────────────────────────────────────────────────
  - id: anti_amnesia_check
    name: "Anti-amnesia: excluir leads que respondieron recientemente"
    agent: script-runner
    action: check_last_interaction_batch
    depends_on:
      - filter_max_attempts
    params:
      source: filter_max_attempts
      table: interactions
      check_field: "tipo"
      exclude_if_last_is: "mensaje_entrante"
      mark_as: "RESPONDED"
      log_skipped: true
      log_message: "⚠️ SALTO → {nombre} ({telefono}) - Lead respondió hace poco. Prioridad Humana."

  # ─── PASO 10: Seleccionar un lead al azar ─────────────────────────────────
  - id: select_one_lead
    name: "Seleccionar un lead al azar de los elegibles"
    agent: script-runner
    action: random_pick
    depends_on:
      - anti_amnesia_check
    params:
      source: anti_amnesia_check
      count: 1
      shuffle: true
      on_empty: stop_pipeline
      on_empty_log: "No hay leads elegibles"

  # ─── PASO 11: Drift pre-acción ────────────────────────────────────────────
  - id: pre_action_drift
    name: "Espera humana de inicio (30-300s)"
    agent: script-runner
    action: random_sleep
    depends_on:
      - select_one_lead
    params:
      min_seconds: "${safety.pre_action_drift.min_seconds}"
      max_seconds: "${safety.pre_action_drift.max_seconds}"
      log_message: "⏳ Espera humana: {sleep_seconds}s..."

  # ─── PASO 12: Preparar mensaje ────────────────────────────────────────────
  - id: prepare_message
    name: "Limpiar nombre + seleccionar mensaje del pool (sin repetir)"
    agent: script-runner
    action: prepare_reactivation_message
    depends_on:
      - pre_action_drift
    params:
      lead: "${select_one_lead.lead}"
      name_cleaning: "${name_cleaning}"
      message_pool: "${message_pool}"
      enrich_with_area: true
      area_field: "zona_preferida"

  # ─── PASO 13: Clasificar agente de envío ──────────────────────────────────
  - id: classify_sender
    name: "Asignar agente según canal de origen"
    agent: script-runner
    action: classify_sender
    depends_on:
      - prepare_message
    params:
      lead: "${select_one_lead.lead}"
      rules:
        - condition: "lead.es_internacional == true"
          sender: "jeanette"
        - condition: "lead.canal_origen in ['facebook', 'instagram']"
          sender: "rose"
        - condition: "lead.canal_origen in ['gumtree', 'rightmove', 'zoopla', 'spareroom', 'openrent']"
          sender: "salo"
        - condition: "default"
          sender: "ivy"

  # ─── PASO 14: Despachar al agente ─────────────────────────────────────────
  - id: dispatch_message
    name: "Enviar mensaje vía agente asignado (WhatsApp)"
    action: dispatch_to_agent
    depends_on:
      - prepare_message
      - classify_sender
    params:
      target_agent: "${classify_sender.sender}"
      action: whatsapp_send
      payload:
        phone: "${select_one_lead.lead.telefono}"
        message: "${prepare_message.final_message}"

  # ─── PASO 15: Registrar envío + reportar a Alex ───────────────────────────
  - id: log_and_report
    name: "Registrar éxito y reportar a Alex"
    agent: script-runner
    action: log_action
    depends_on:
      - dispatch_message
    condition: "${dispatch_message.success}"
    params:
      accion: "reactivation_sent"
      exito: true
      metadata:
        lead_id: "${select_one_lead.lead.id}"
        lead_nombre: "${prepare_message.clean_name}"
        lead_telefono: "${select_one_lead.lead.telefono}"
        sender_agent: "${classify_sender.sender}"
        message_template: "${prepare_message.template_used}"
        reactivation_count: "${select_one_lead.lead.reactivation_count + 1}"
        sent_today: "${count_sent_today.count + 1}"
        daily_limit: "${get_daily_limit.limit}"

  # ─── PASO 16: Actualizar lead en Supabase ─────────────────────────────────
  - id: update_lead
    name: "Actualizar ultima_interaccion del lead"
    agent: script-runner
    action: supabase_update
    depends_on:
      - log_and_report
    condition: "${dispatch_message.success}"
    params:
      table: leads
      filter: "id.eq.${select_one_lead.lead.id}"
      set:
        ultima_interaccion: "${now}"

  # ─── PASO 17: Cooldown post-envío (22:50 - 42:33 min) ────────────────────
  - id: post_send_cooldown
    name: "Ocultamiento bot: cooldown 22-42 min"
    agent: script-runner
    action: random_sleep
    depends_on:
      - update_lead
    params:
      min_seconds: "${safety.cooldown_between_messages.min_seconds}"
      max_seconds: "${safety.cooldown_between_messages.max_seconds}"
      log_message: "🕐 Cooldown: durmiendo {sleep_minutes}m {sleep_remaining_seconds}s..."

  # ─── PASO 18: Loop — siguiente lead ───────────────────────────────────────
  - id: loop_next_lead
    name: "Siguiente lead (volver al control de horario)"
    action: goto_step
    depends_on:
      - post_send_cooldown
    params:
      target: check_working_hours
      # Se detiene cuando:
      # - Fuera de horario 7-17 London (paso 2)
      # - Alex lo detuvo/pausó (paso 3)
      # - Límite diario alcanzado (paso 6)
      # - No quedan leads elegibles (paso 10)

# =============================================================================
# ERROR HANDLING — siempre reporta a Alex
# =============================================================================
on_error:
  - action: log_action
    params:
      accion: "reactivator_error"
      exito: false
      metadata:
        error: "${error.message}"
        step: "${error.step_id}"
  - action: report_to_alex
    params:
      event: reactivator.error
      message: "❌ Reactivator error en paso ${error.step_id}: ${error.message}"
  - action: telegram_send
    params:
      message: "⚠️ Reactivator error: ${error.message} (step: ${error.step_id})"
      chat_id: "${TELEGRAM_CHAT_ID}"

# =============================================================================
# SESIÓN COMPLETADA — UN solo reporte final a Alex (a las 5PM o al terminar)
# =============================================================================
on_complete:
  - action: telegram_send
    always_run: true
    params:
      chat_id: "${TELEGRAM_CHAT_ID}"
      message: |
        😴 **Reactivator — Reporte del día**

        Jefe, terminé mi turno. Aquí el resumen:

        📤 **Mensajes enviados:** ${session.total_dispatched}/${get_daily_limit.limit}
        💬 **Leads que respondieron (saltados):** ${session.total_skipped_responded}
        🚫 **Leads agotados (5+ intentos):** ${session.total_skipped_max_attempts}
        👻 **Leads elegibles restantes:** ${session.remaining_eligible}
        ⏱️ **Duración de la sesión:** ${session.duration_minutes} min

        Voy a descansar jefe, mañana a las 7 arranco de nuevo. 🫡
  - action: log_action
    always_run: true
    params:
      accion: "reactivator_session_completed"
      metadata:
        total_sent: "${session.total_dispatched}"
        total_skipped_responded: "${session.total_skipped_responded}"
        total_skipped_max_attempts: "${session.total_skipped_max_attempts}"
        remaining_eligible: "${session.remaining_eligible}"
        daily_limit: "${get_daily_limit.limit}"
        session_duration_minutes: "${session.duration_minutes}"
