# Pipeline: Daily Follow-up Check (WhatsApp Alerts)
# Ejecuta cada día a las 9:00 AM Europe/London
# Envía alertas a las agentes por WhatsApp

name: daily-followup-check
description: "Revisa followups y tasks - alerta a agentes por WhatsApp"
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

  # ─── 3. Resumen para el Owner (Telegram) ───────────────────────────────
  - id: send_owner_summary
    name: "Enviar resumen al owner por Telegram"
    agent: alex
    action: telegram_send
    params:
      message: |
        📊 *RESUMEN OPERACIONES - {{date}}*

        *Followups Hoy:*
        • Ivy: {{check_followups_hoy.results.filter(f => f.agente_asignado === 'ivy').length}}
        • Rose: {{check_followups_hoy.results.filter(f => f.agente_asignado === 'rose').length}}
        • Salo: {{check_followups_hoy.results.filter(f => f.agente_asignado === 'salo').length}}
        • Jeanette: {{check_followups_hoy.results.filter(f => f.agente_asignado === 'jeanette').length}}

        *Tasks Hoy:*
        • Ivy: {{check_tasks_hoy.results.filter(t => t.agente_asignado === 'ivy').length}}
        • Rose: {{check_tasks_hoy.results.filter(t => t.agente_asignado === 'rose').length}}
        • Salo: {{check_tasks_hoy.results.filter(t => t.agente_asignado === 'salo').length}}
        • Jeanette: {{check_tasks_hoy.results.filter(t => t.agente_asignado === 'jeanette').length}}

        _Las agentes reciben sus alertas por WhatsApp._
      chat_id: "${TELEGRAM_CHAT_ID}"
      parse_mode: "Markdown"

  # ─── 4. Enviar alertas por WhatsApp a cada agente ───────────────────────
  - id: alert_ivy_whatsapp
    name: "Alertar a Ivy por WhatsApp"
    agent: alex
    action: script
    command: python3
    params:
      script: |
        import sys
        sys.path.append('/home/ubuntu/rentinlondon-pro/openclaw/services')
        from whatsapp_alert_service import send_alerts_to_agents, get_supabase_client
        supabase = get_supabase_client()
        
        followups = {{check_followups_hoy.results}}
        tasks = {{check_tasks_hoy.results}}
        
        # Filtrar para Ivy
        ivy_followups = [f for f in followups if f.get('agente_asignado') == 'ivy']
        ivy_tasks = [t for t in tasks if t.get('agente_asignado') == 'ivy']
        
        messages = []
        if ivy_followups:
            messages.append(f"🔔 *SEGUIMIENTO HOY*")
            for f in ivy_followups:
                messages.append(f"• {f.get('nombre')} - {f.get('zona_preferida')} - SCL: {f.get('scl_score')}")
        if ivy_tasks:
            messages.append(f"📋 *TAREAS HOY*")
            for t in ivy_tasks:
                messages.append(f"• {t.get('titulo')} - {t.get('nombre')}")
        
        if messages:
            print('\\n'.join(messages))
        else:
            print("No hay tareas pendientes para hoy")
    on_output:
      - action: wacli_send
        params:
          phone: "${IVY_WHATSAPP_NUMBER}"
          message: "${output}"

  - id: alert_rose_whatsapp
    name: "Alertar a Rose por WhatsApp"
    agent: alex
    action: script
    depends_on:
      - check_followups_hoy
      - check_tasks_hoy
    command: python3
    params:
      script: |
        import sys
        sys.path.append('/home/ubuntu/rentinlondon-pro/openclaw/services')
        
        followups = {{check_followups_hoy.results}}
        tasks = {{check_tasks_hoy.results}}
        
        rose_followups = [f for f in followups if f.get('agente_asignado') == 'rose']
        rose_tasks = [t for t in tasks if t.get('agente_asignado') == 'rose']
        
        messages = []
        if rose_followups:
            messages.append(f"🔔 *SEGUIMIENTO HOY*")
            for f in rose_followups:
                messages.append(f"• {f.get('nombre')} - {f.get('zona_preferida')} - SCL: {f.get('scl_score')}")
        if rose_tasks:
            messages.append(f"📋 *TAREAS HOY*")
            for t in rose_tasks:
                messages.append(f"• {t.get('titulo')} - {t.get('nombre')}")
        
        if messages:
            print('\\n'.join(messages))
        else:
            print("No hay tareas pendientes para hoy")

  - id: alert_salo_whatsapp
    name: "Alertar a Salo por WhatsApp"
    agent: alex
    action: script
    depends_on:
      - check_followups_hoy
      - check_tasks_hoy
    command: python3
    params:
      script: |
        import sys
        sys.path.append('/home/ubuntu/rentinlondon-pro/openclaw/services')
        
        followups = {{check_followups_hoy.results}}
        tasks = {{check_tasks_hoy.results}}
        
        salo_followups = [f for f in followups if f.get('agente_asignado') == 'salo']
        salo_tasks = [t for t in tasks if t.get('agente_asignado') == 'salo']
        
        messages = []
        if salo_followups:
            messages.append(f"🔔 *SEGUIMIENTO HOY*")
            for f in salo_followups:
                messages.append(f"• {f.get('nombre')} - {f.get('zona_preferida')} - SCL: {f.get('scl_score')}")
        if salo_tasks:
            messages.append(f"📋 *TAREAS HOY*")
            for t in salo_tasks:
                messages.append(f"• {t.get('titulo')} - {t.get('nombre')}")
        
        if messages:
            print('\\n'.join(messages))
        else:
            print("No hay tareas pendientes para hoy")

  - id: alert_jeanette_whatsapp
    name: "Alertar a Jeanette por WhatsApp"
    agent: alex
    action: script
    depends_on:
      - check_followups_hoy
      - check_tasks_hoy
    command: python3
    params:
      script: |
        import sys
        sys.path.append('/home/ubuntu/rentinlondon-pro/openclaw/services')
        
        followups = {{check_followups_hoy.results}}
        tasks = {{check_tasks_hoy.results}}
        
        jeanette_followups = [f for f in followups if f.get('agente_asignado') == 'jeanette']
        jeanette_tasks = [t for t in tasks if t.get('agente_asignado') == 'jeanette']
        
        messages = []
        if jeanette_followups:
            messages.append(f"🔔 *SEGUIMIENTO HOY*")
            for f in jeanette_followups:
                messages.append(f"• {f.get('nombre')} - {f.get('zona_preferida')} - SCL: {f.get('scl_score')}")
        if jeanette_tasks:
            messages.append(f"📋 *TAREAS HOY*")
            for t in jeanette_tasks:
                messages.append(f"• {t.get('titulo')} - {t.get('nombre')}")
        
        if messages:
            print('\\n'.join(messages))
        else:
            print("No hay tareas pendientes para hoy")

  # ─── 5. Log de ejecución ─────────────────────────────────────────────────
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

# Error handling
on_error:
  - action: telegram_send
    params:
      message: "⚠️ Error en daily-followup-check: ${error.message}"
      chat_id: "${TELEGRAM_CHAT_ID}"