# Pipeline: Nurturing Automation
# Ejecuta cada día a las 10:00 AM para procesar secuencias de nurturing

name: nurturing-automation
description: "Procesa secuencias de nurturing automatizado"
timezone: Europe/London
schedule: "0 10 * * 1-6"  # Lun-Sáb 10AM London

steps:
  # ─── 1. Obtener secuencias que deben ejecutarse hoy ─────────────────────
  - id: get_active_sequences
    name: "Obtener secuencias activas para hoy"
    agent: script
    action: supabase_query
    params:
      table: lead_nurturing_sequences
      select: "id,lead_id,tipo_secuencia,paso_actual,total_pasos,parametros"
      filter: "estado.eq.activa"
      limit: 100

  # ─── 2. Procesar cada secuencia ─────────────────────────────────────────
  - id: process_sequences
    name: "Procesar secuencias de nurturing"
    agent: script
    action: for_each
    depends_on:
      - get_active_sequences
    loop_over: "${get_active_sequences.results}"
    iterator_name: "sequence"
    steps:
      # Determinar mensaje según tipo de secuencia y paso
      - id: determine_message
        name: "Determinar mensaje a enviar"
        agent: script
        action: switch
        value: "${sequence.tipo_secuencia}"
        cases:
          welcome:
            output: "Hi {{sequence.lead_nombre}}, thanks for reaching out! Just checking you're still looking for a place. Let me know if you have any questions."
          follow_up_3dias:
            output: "Hi {{sequence.lead_nombre}}, just following up from our last chat. Have you had a chance to think about it?"
          follow_up_7dias:
            output: "Hi {{sequence.lead_nombre}}, just checking in. Still interested? We have some new properties that might interest you."
          post_viewing:
            output: "Hi {{sequence.lead_nombre}}, thanks for coming in yesterday! How did you like the place? Let me know your thoughts."
          post_booking:
            output: "Hi {{sequence.lead_nombre}}, just confirming your appointment for tomorrow. See you at 154 Bishopsgate!"
          reactivacion:
            output: "Hi {{sequence.lead_nombre}}, it's been a while! We're back with some new options. Still looking?"
          intl_welcome:
            output: "Hi {{sequence.lead_nombre}}, welcome! I can help you with video tours so you can see properties remotely. When would be a good time for a call?"
          default:
            output: "Hi {{sequence.lead_nombre}}, just checking in!"

      # Enviar mensaje vía WhatsApp (simulado - integración real requiere webhooks)
      - id: send_nurture_message
        name: "Enviar mensaje de nurturing"
        agent: script
        action: supabase_insert
        depends_on:
          - determine_message
        params:
          table: interactions
          lead_id: "${sequence.lead_id}"
          agente: "system"
          canal: "whatsapp"
          tipo: "mensaje_saliente"
          contenido: "${determine_message.output}"

      # Actualizar secuencia al siguiente paso
      - id: advance_sequence
        name: "Avanzar al siguiente paso"
        agent: script
        depends_on:
          - send_nurture_message
        action: rpc_call
        params:
          function: fn_next_nurturing_step
          arguments:
            p_seq_id: "${sequence.id}"

  # ─── 3. Log de ejecución ─────────────────────────────────────────────────
  - id: log_completion
    name: "Registrar ejecución"
    agent: script
    action: log_action
    always_run: true
    params:
      accion: "nurturing_automation_completed"
      exito: "${pipeline.success}"

on_error:
  - action: telegram_send
    params:
      message: "⚠️ Error en nurturing-automation: ${error.message}"
      chat_id: "${TELEGRAM_CHAT_ID}"