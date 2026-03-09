# Pipeline: Dormant Lead Reactivation
# Ejecuta todos los miércoles a las 10:00 AM Europe/London
# Script-Runner prepara mensajes — Alex los aprueba — Ivy/Jeanette los envían

name: dormant-reactivation
description: "Reactivación de leads dormidos con aprobación humana — NUNCA envía sin aprobación"
timezone: Europe/London
schedule: "0 10 * * 3"

steps:
  - id: query_dormant
    name: "Obtener lista completa de leads dormantes"
    agent: script-runner
    action: supabase_query
    params:
      view: v_leads_dormantes
      filter: "dias_sin_contacto.gte.7"
      order: "urgency_score.desc,dias_sin_contacto.desc"
      limit: 50

  - id: classify_dormant
    name: "Clasificar leads por tipo y agente responsable"
    agent: script-runner
    action: classify_batch
    depends_on:
      - query_dormant
    params:
      rules:
        - condition: "lead.es_internacional == true"
          assigned_sender: "jeanette"
          message_template: "reactivation_intl"
        - condition: "lead.canal_origen in ['facebook', 'instagram']"
          assigned_sender: "rose"
          message_template: "reactivation_ads"
        - condition: "lead.canal_origen in ['gumtree', 'rightmove', 'zoopla', 'spareroom', 'openrent']"
          assigned_sender: "salo"
          message_template: "reactivation_marketplace"
        - condition: "lead.dias_sin_contacto >= 30"
          assigned_sender: "ivy"
          message_template: "reactivation_final"
        - condition: "default"
          assigned_sender: "ivy"
          message_template: "reactivation_standard"

  - id: prepare_messages
    name: "Preparar mensajes de reactivación personalizados"
    agent: script-runner
    action: prepare_reactivation_batch
    depends_on:
      - classify_dormant
    params:
      personalization:
        include_zona: true
        include_last_property: true
        include_days_dormant: false
        include_name: true
      max_messages: 30
      note: "NUNCA enviar directamente — requiere aprobación de Alex"

  - id: queue_for_approval
    name: "Poner en cola de aprobación (agent_logs)"
    agent: script-runner
    action: supabase_insert_batch
    depends_on:
      - prepare_messages
    params:
      table: agent_logs
      data_template:
        agente: "script-runner"
        accion: "reactivation_prepared"
        exito: true
        metadata:
          requires_approval: true
          status: "pending_approval"
          message_draft: "${message.text}"
          assigned_sender: "${message.assigned_sender}"
          message_template: "${message.template}"

  - id: notify_alex_for_approval
    name: "Notificar a Alex para revisión y aprobación"
    agent: script-runner
    action: internal_notify
    depends_on:
      - queue_for_approval
    params:
      target_agent: alex
      event: reactivation.pending_approval
      payload:
        count: "${prepare_messages.count}"
        approval_required: true
        message: "Script-Runner ha preparado ${prepare_messages.count} mensajes de reactivación para tu revisión"

  - id: send_approval_request_telegram
    name: "Enviar solicitud de aprobación al dueño vía Telegram"
    agent: alex
    action: telegram_send
    depends_on:
      - notify_alex_for_approval
    params:
      chat_id: "${TELEGRAM_CHAT_ID}"
      message: |
        🔄 **Reactivación de Leads Dormidos — Aprobación Requerida**

        Script-Runner preparó **${prepare_messages.count}** mensajes de reactivación:
        
        • Leads dormantes 7-14 días: ${count_7_14}
        • Leads dormantes 14-30 días: ${count_14_30}
        • Leads dormantes 30+ días: ${count_30plus}
        
        **Para aprobar y enviar**:
        `/aprobar_reactivacion` — Envía todos los mensajes
        `/revisar_reactivacion` — Ver mensajes uno por uno
        `/cancelar_reactivacion` — No enviar ninguno
        
        ⚠️ *Los mensajes NO se enviarán hasta que apruebes.*

  - id: log_pipeline
    name: "Registrar ejecución del pipeline"
    agent: script-runner
    action: log_action
    always_run: true
    params:
      accion: "dormant_reactivation_pipeline_completed"
      metadata:
        dormant_leads_found: "${query_dormant.count}"
        messages_prepared: "${prepare_messages.count}"
        status: "pending_human_approval"

# Cuando Alex aprueba (comando /aprobar_reactivacion):
on_approval:
  - id: send_approved_messages
    name: "Enviar mensajes aprobados vía agentes asignados"
    action: dispatch_approved_messages
    params:
      source_table: agent_logs
      filter: "accion.eq.reactivation_prepared.metadata->requires_approval.eq.true.metadata->status.eq.pending_approval"
      dispatch_rules:
        ivy:
          action: whatsapp_send
        rose:
          action: whatsapp_send
        salo:
          action: whatsapp_send
        jeanette:
          action: whatsapp_send
    update_after_send:
      table: agent_logs
      set:
        metadata->status: "sent"
        metadata->sent_at: "${now}"

on_error:
  - action: telegram_send
    params:
      message: "⚠️ Error en dormant-reactivation pipeline: ${error.message}"
      chat_id: "${TELEGRAM_CHAT_ID}"
