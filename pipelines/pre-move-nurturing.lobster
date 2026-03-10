# Pipeline: Pre-Move Nurturing
# Se ejecuta todos los días a las 8:30 AM Europe/London
# Identifica leads con fecha_mudanza a 30, 15, 7 y 3 días
# y activa secuencias de seguimiento personalizadas por agente
#
# Ventanas de contacto:
#   30 días → Verificar si sigue buscando, enviar opciones nuevas
#   15 días → Confirmar disponibilidad, agendar viewing si no se ha hecho
#   7 días  → Urgente: ¿tienes depósito listo? ¿necesitas ayuda?
#   3 días  → Última oportunidad: propiedades disponibles ahora mismo

name: pre-move-nurturing
description: "Seguimiento proactivo de leads según proximidad de su fecha de mudanza"
timezone: Europe/London
schedule: "30 8 * * *"

steps:
  - id: query_pre_move
    name: "Consultar leads con fecha de mudanza próxima"
    agent: script-runner
    action: supabase_query
    params:
      view: v_seguimiento_pre_mudanza
      # La vista ya filtra por ventanas 30/15/7/3 días automáticamente
      order: "fecha_mudanza.asc,urgency_score.desc"
      limit: 100

  - id: check_empty
    name: "Verificar si hay leads que procesar hoy"
    agent: script-runner
    action: check_count
    depends_on:
      - query_pre_move
    params:
      source: query_pre_move
      on_empty: skip_pipeline
      on_empty_log: "No hay leads en ventanas de seguimiento hoy — pipeline completado sin acción"

  - id: group_by_window
    name: "Agrupar leads por ventana de seguimiento"
    agent: script-runner
    action: group_by_field
    depends_on:
      - query_pre_move
    params:
      field: ventana_seguimiento
      groups:
        - key: "30_dias"
          label: "Ventana de 30 días"
        - key: "15_dias"
          label: "Ventana de 15 días"
        - key: "7_dias"
          label: "Ventana de 7 días"
        - key: "3_dias"
          label: "Ventana de 3 días"

  - id: prepare_messages_30d
    name: "Preparar mensajes para leads en ventana de 30 días"
    agent: script-runner
    action: prepare_nurture_batch
    depends_on:
      - group_by_window
    params:
      group: "30_dias"
      template: "nurture_30_dias"
      message_variables:
        - nombre
        - zona_preferida
        - tipo_propiedad
        - presupuesto_max
      personalization:
        include_zona: true
        include_tipo: true
        include_budget_range: false

  - id: prepare_messages_15d
    name: "Preparar mensajes para leads en ventana de 15 días"
    agent: script-runner
    action: prepare_nurture_batch
    depends_on:
      - group_by_window
    params:
      group: "15_dias"
      template: "nurture_15_dias"
      message_variables:
        - nombre
        - zona_preferida
        - tipo_propiedad
      personalization:
        include_zona: true
        include_tipo: true
        suggest_viewing: true

  - id: prepare_messages_7d
    name: "Preparar mensajes urgentes para leads en ventana de 7 días"
    agent: script-runner
    action: prepare_nurture_batch
    depends_on:
      - group_by_window
    params:
      group: "7_dias"
      template: "nurture_7_dias"
      message_variables:
        - nombre
        - zona_preferida
        - tipo_propiedad
        - presupuesto_max
      personalization:
        include_zona: true
        include_tipo: true
        mention_deposit: true
        urgent_tone: true

  - id: prepare_messages_3d
    name: "Preparar mensajes de última oportunidad para leads en ventana de 3 días"
    agent: script-runner
    action: prepare_nurture_batch
    depends_on:
      - group_by_window
    params:
      group: "3_dias"
      template: "nurture_3_dias"
      message_variables:
        - nombre
        - zona_preferida
        - tipo_propiedad
        - presupuesto_max
      personalization:
        include_zona: true
        include_tipo: true
        mention_deposit: true
        urgent_tone: true
        last_chance: true

  - id: queue_for_approval
    name: "Encolar todos los mensajes para aprobación de Alex"
    agent: script-runner
    action: supabase_insert_batch
    depends_on:
      - prepare_messages_30d
      - prepare_messages_15d
      - prepare_messages_7d
      - prepare_messages_3d
    params:
      table: agent_logs
      data_template:
        agente: "script-runner"
        accion: "pre_move_nurture_prepared"
        exito: true
        metadata:
          requires_approval: true
          status: "pending_approval"
          pipeline: "pre-move-nurturing"
          ventana: "${message.ventana_seguimiento}"
          message_draft: "${message.text}"
          assigned_sender: "${message.agente_recomendado}"
          message_template: "${message.template}"
          lead_fecha_mudanza: "${message.fecha_mudanza}"
          dias_restantes: "${message.dias_para_mudanza}"

  - id: notify_alex
    name: "Notificar a Alex con resumen diario de seguimiento"
    agent: alex
    action: telegram_send
    depends_on:
      - queue_for_approval
    params:
      chat_id: "${TELEGRAM_CHAT_ID}"
      message: |
        📅 **Seguimiento Pre-Mudanza — ${today_london}**

        Leads a contactar hoy según proximidad de mudanza:

        🔴 **En 3 días:** ${count_3_dias} lead(s) — última oportunidad
        🟠 **En 7 días:** ${count_7_dias} lead(s) — urgente
        🟡 **En 15 días:** ${count_15_dias} lead(s) — confirmar viewing
        🟢 **En 30 días:** ${count_30_dias} lead(s) — verificar interés

        **Total de mensajes preparados:** ${total_mensajes}

        **Para aprobar y enviar:**
        `/aprobar_premove` — Envía todos los mensajes
        `/revisar_premove` — Ver mensajes uno por uno
        `/cancelar_premove` — No enviar ninguno

        ⚠️ *Los mensajes NO se enviarán hasta tu aprobación.*

  - id: log_pipeline
    name: "Registrar ejecución del pipeline en base de datos"
    agent: script-runner
    action: log_action
    always_run: true
    params:
      accion: "pre_move_nurturing_pipeline_completed"
      metadata:
        leads_en_ventana_30d: "${count_30_dias}"
        leads_en_ventana_15d: "${count_15_dias}"
        leads_en_ventana_7d: "${count_7_dias}"
        leads_en_ventana_3d: "${count_3_dias}"
        total_mensajes_preparados: "${total_mensajes}"
        status: "pending_human_approval"
        fecha_ejecucion_london: "${today_london}"

# Cuando Alex aprueba (/aprobar_premove):
on_approval:
  - id: dispatch_nurture_messages
    name: "Enviar mensajes aprobados a través de los agentes asignados"
    action: dispatch_approved_messages
    params:
      source_table: agent_logs
      filter: "accion.eq.pre_move_nurture_prepared.metadata->requires_approval.eq.true.metadata->status.eq.pending_approval"
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
      message: "⚠️ Error en pre-move-nurturing pipeline: ${error.message}"
      chat_id: "${TELEGRAM_CHAT_ID}"

# ─── Plantillas de mensajes (referencia para script-runner) ───────────────────
# Los agentes adaptan el tono según el SOUL de cada uno

message_templates:
  nurture_30_dias: |
    Hola ${nombre} 👋 
    Hace unas semanas estuviste buscando piso en ${zona_preferida}. 
    ¿Sigues buscando ${tipo_propiedad} para el próximo mes? 
    Tenemos opciones nuevas que podrían interesarte.

  nurture_15_dias: |
    Hola ${nombre}, somos RentInLondon.
    Tu fecha de mudanza se acerca — ¿ya tienes algo cerrado? 
    Si no, nos gustaría mostrarte propiedades disponibles en ${zona_preferida} 
    que se ajustan a lo que buscas. ¿Podemos agendar un viewing esta semana?

  nurture_7_dias: |
    Hola ${nombre} 🏠
    Quedan solo 7 días para tu fecha de mudanza. 
    ¿Tienes el depósito listo? ¿Necesitas ayuda urgente para encontrar algo en ${zona_preferida}?
    Podemos mostrarte opciones disponibles HOY.

  nurture_3_dias: |
    Hola ${nombre}, es urgente.
    Tu mudanza es en 3 días. Si aún no tienes piso confirmado, 
    tenemos propiedades disponibles AHORA en ${zona_preferida}.
    Escríbenos y te ayudamos hoy mismo.
