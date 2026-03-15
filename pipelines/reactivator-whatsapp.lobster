# =============================================================================
# Pipeline: reactivator-whatsapp
# Envía mensajes de reactivación directamente por WhatsApp de Jeanette
# =============================================================================

name: reactivator-whatsapp
description: "Reactivación automática por WhatsApp"
timezone: Europe/London

safety:
  working_hours:
    monday_to_friday:
      start: "10:00"
      end: "20:00"
    saturday:
      start: "10:00"
      end: "17:00"
    sunday:
      start: "10:00"
      end: "15:00"
    timezone: Europe/London
    enforce: strict

  cooldown_seconds: 60

message_pool:
  templates:
    - "Hi {name}, Jeanette here from RentInLondon — quick question: still looking for a room in London?"
    - "Hey {name}, it's Jeanette checking in. Are you still searching for a place in London?"
    - "Hi {name}, just checking in — are you still looking for accommodation in London?"
    - "Hello {name}, Jeanette here. We have some new rooms available — still interested?"
    - "Hi {name}, hope you're well! Any update on your room search in London?"
    - "Hey {name}, Jeanette from RentInLondon checking in. Still need a place?"

steps:
  # 1. Verificar horario
  - id: check_hours
    name: "Check London working hours"
    agent: script-runner
    action: check_working_hours
    params:
      rules: "${safety.working_hours}"
      on_outside_hours: stop_pipeline

  # 2. Get dormant leads
  - id: get_dormant
    name: "Get dormant leads"
    agent: script-runner
    action: supabase_query
    depends_on:
      - check_hours
    params:
      table: v_leads_dormantes
      filter: "dias_sin_contacto.gte.7"
      order: "dias_sin_contacto.desc"
      limit: 5

  # 3. Select one lead
  - id: select_lead
    name: "Select random lead"
    agent: script-runner
    action: random_pick
    depends_on:
      - get_dormant
    params:
      source: get_dormant
      count: 1

  # 4. Format message
  - id: format_msg
    name: "Format WhatsApp message"
    agent: script-runner
    action: format_message
    depends_on:
      - select_lead
    params:
      template: "Hi {name}, Jeanette here from RentInLondon — quick question: still looking for a room in London?"
      variables:
        name: "${select_lead.item.nombre}"

  # 5. Send WhatsApp via CLI
  - id: send_wa
    name: "Send WhatsApp message"
    agent: script-runner
    action: exec
    depends_on:
      - format_msg
    params:
      command: "source ~/.nvm/nvm.sh && openclaw message send --channel whatsapp --target ${select_lead.item.telefono} --message \"${format_msg.formatted}\""

  # 6. Log
  - id: log_result
    name: "Log result"
    agent: script-runner
    action: log_action
    depends_on:
      - send_wa
    params:
      accion: "reactivation_whatsapp_sent"
      metadata:
        lead_id: "${select_lead.item.id}"
        lead_nombre: "${select_lead.item.nombre}"
        lead_telefono: "${select_lead.item.telefono}"
        success: "${send_wa.success}"

  # 7. Report to Alex
  - id: report
    name: "Report to Alex"
    agent: script-runner
    action: report_to_alex
    depends_on:
      - log_result
    params:
      message: "✅ Reactivator: Mensaje enviado a ${select_lead.item.nombre} (${select_lead.item.telefono})"
