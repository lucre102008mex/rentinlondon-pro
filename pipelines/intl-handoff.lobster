# Pipeline: International Handoff
# Ejecuta cada 30 minutos — detecta leads internacionales sin asignar
# Transfiere a Jeanette en < 30 minutos de la creación del lead

name: intl-handoff
description: "Detecta y transfiere leads internacionales a Jeanette en tiempo real"
timezone: Europe/London
schedule: "*/30 * * * *"

steps:
  - id: detect_intl_leads
    name: "Detectar leads internacionales sin asignar a Jeanette"
    agent: alex
    action: supabase_query
    params:
      table: leads
      filter: |
        es_internacional.eq.true
        AND escalado_jeanette.eq.false
        AND status.not.in.(rechazado,perdido,contrato_firmado)
        AND created_at.gte.now_minus_2h
      select: "id,nombre,telefono,canal_origen,pais_origen,zona_preferida,presupuesto_max,tipo_propiedad,fecha_mudanza,asignado_a,urgency_score,created_at"
      order: "urgency_score.desc,created_at.asc"

  - id: check_if_any
    name: "Verificar si hay leads a transferir"
    agent: alex
    action: check_count
    depends_on:
      - detect_intl_leads
    params:
      source: "${detect_intl_leads.results}"
      skip_if_empty: true

  - id: assign_to_jeanette
    name: "Asignar leads a Jeanette en Supabase"
    agent: alex
    action: supabase_update_batch
    depends_on:
      - check_if_any
    params:
      table: leads
      ids: "${detect_intl_leads.ids}"
      data:
        asignado_a: "jeanette"
        escalado_jeanette: true
        escalado_at: "${now}"
        motivo_escalado: "Lead internacional detectado por intl-handoff pipeline"
        pipeline_stage: "intake"

  - id: log_escalation
    name: "Registrar escalado en interactions"
    agent: alex
    action: supabase_insert_batch
    depends_on:
      - assign_to_jeanette
    params:
      table: interactions
      data_template:
        agente: "alex"
        canal: "interno"
        tipo: "escalado"
        contenido: "Lead internacional transferido automáticamente a Jeanette"
      ids_source: "${detect_intl_leads.ids}"

  - id: notify_jeanette
    name: "Notificar a Jeanette de nuevos leads internacionales"
    agent: alex
    action: internal_notify
    depends_on:
      - assign_to_jeanette
    params:
      target_agent: jeanette
      event: lead.escalated
      payload:
        leads: "${detect_intl_leads.results}"
        action_required: "initiate_intl_intake"

  - id: notify_owner_if_many
    name: "Alertar al dueño si hay 3+ leads internacionales nuevos"
    agent: alex
    action: conditional_telegram_send
    depends_on:
      - assign_to_jeanette
    params:
      condition: "${detect_intl_leads.count} >= 3"
      chat_id: "${TELEGRAM_CHAT_ID}"
      message: |
        🌍 **Alerta Leads Internacionales**
        ${detect_intl_leads.count} leads internacionales nuevos transferidos a Jeanette
        Países: ${detect_intl_leads.countries_list}
        Hora: ${now_london}

  - id: log_pipeline
    name: "Registrar ejecución del pipeline"
    agent: alex
    action: log_action
    always_run: true
    params:
      accion: "intl_handoff_completed"
      metadata:
        leads_transferred: "${detect_intl_leads.count}"
        execution_time: "${pipeline.duration_ms}"

on_empty:
  - action: noop
    comment: "Sin leads internacionales nuevos — no hacer nada"

on_error:
  - action: telegram_send
    params:
      message: "⚠️ Error en intl-handoff pipeline: ${error.message}"
      chat_id: "${TELEGRAM_CHAT_ID}"
