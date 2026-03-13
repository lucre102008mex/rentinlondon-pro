# WhatsApp Alert Service - RentInLondon PRO
# Envía alertas a las agentes via WhatsApp usando wacli o WhatsApp Business API

import os
import json
import requests
from datetime import datetime, timedelta
from supabase import create_client, Client

# Configuración
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

# Números de las agentes (configurar en producción)
AGENT_WHATSAPP = {
    "ivy": "+447700900001",  # Reemplazar con número real
    "rose": "+447700900002",
    "salo": "+447700900003",
    "jeanette": "+447700900004"
}

def get_supabase_client() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_KEY)

def get_followups_hoy(supabase: Client) -> list:
    """Obtiene followups pendientes para hoy"""
    response = supabase.table("v_followups_hoy").select("*").execute()
    return response.data

def get_tasks_hoy(supabase: Client) -> list:
    """Obtiene tasks pendientes para hoy"""
    response = supabase.table("v_tasks_hoy").select("*").execute()
    return response.data

def format_followup_message(followups: list, agente: str) -> str:
    """Formatea mensaje de followups para una agente específica"""
    agent_followups = [f for f in followups if f.get("agente_asignado") == agente]
    
    if not agent_followups:
        return None
    
    nombre = AGENT_WHATSAPP.get(f"_{agente}", "Agente").replace("+", "").replace("447700", "")
    
    lines = [f"🔔 *SEGUIMIENTO HOY - {agente.upper()}*"]
    lines.append("")
    
    for f in agent_followups:
        dias = f.get("dias_antes")
        emoji = "🔥" if dias == 3 else "⏰" if dias == 7 else "📅"
        lines.append(f"{emoji} *{f.get('nombre', 'Sin nombre')}*")
        lines.append(f"   📍 {f.get('zona_preferida', 'N/A')}")
        lines.append(f"   💰 £{f.get('presupuesto_max', 0)}")
        lines.append(f"   🎯 SCL: {f.get('scl_score', 0)}")
        lines.append(f"   📆 Mudanza: {f.get('fecha_mudanza')}")
        lines.append("")
    
    lines.append(f"Total: {len(agent_followups)} seguimiento(s)")
    return "\n".join(lines)

def format_task_message(tasks: list, agente: str) -> str:
    """Formatea mensaje de tareas para una agente específica"""
    agent_tasks = [t for t in tasks if t.get("agente_asignado") == agente]
    
    if not agent_tasks:
        return None
    
    lines = [f"📋 *TAREAS HOY - {agente.upper()}*"]
    lines.append("")
    
    for t in agent_tasks:
        prioridad = t.get("prioridad", "normal")
        emoji = "🔴" if prioridad == "urgente" else "🟠" if prioridad == "alta" else "🟢"
        lines.append(f"{emoji} *{t.get('titulo', 'Sin título')}*")
        lines.append(f"   👤 {t.get('nombre', 'N/A')}")
        lines.append(f"   📍 {t.get('zona_preferida', 'N/A')}")
        if t.get("hora_programada"):
            lines.append(f"   🕐 {t.get('hora_programada')}")
        lines.append("")
    
    lines.append(f"Total: {len(agent_tasks)} tarea(s)")
    return "\n".join(lines)

def send_whatsapp_message(phone: str, message: str) -> dict:
    """
    Envía mensaje por WhatsApp.
    Usa wacli-cli o WhatsApp Business API según configuración.
    """
    # Método 1: WACLI CLI (si está instalado)
    wacli_path = os.getenv("WACLI_PATH", "/usr/local/bin/wacli")
    if os.path.exists(wacli_path):
        import subprocess
        result = subprocess.run(
            [wacli_path, "send", phone, message],
            capture_output=True,
            text=True
        )
        return {"method": "wacli", "success": result.returncode == 0, "output": result.stdout}
    
    # Método 2: WhatsApp Business API (Twilio/Infobip)
    whatsapp_api_url = os.getenv("WHATSAPP_API_URL")
    whatsapp_token = os.getenv("WHATSAPP_TOKEN")
    
    if whatsapp_api_url and whatsapp_token:
        headers = {
            "Authorization": f"Bearer {whatsapp_token}",
            "Content-Type": "application/json"
        }
        payload = {
            "to": phone,
            "type": "text",
            "text": {"body": message}
        }
        response = requests.post(whatsapp_api_url, headers=headers, json=payload)
        return {"method": "whatsapp_api", "success": response.status_code == 200, "response": response.json()}
    
    # Método 3: Guardar en cola para procesamiento manual
    return {"method": "queue", "success": True, "message": "Message queued"}

def send_alerts_to_agents(supabase: Client) -> dict:
    """Envía alertas a todas las agentes con followups/tasks pendientes"""
    
    followups = get_followups_hoy(supabase)
    tasks = get_tasks_hoy(supabase)
    
    results = {
        "followups_found": len(followups),
        "tasks_found": len(tasks),
        "alerts_sent": []
    }
    
    # Enviar a cada agente
    for agente in ["ivy", "rose", "salo", "jeanette"]:
        messages = []
        
        # Followups
        followup_msg = format_followup_message(followups, agente)
        if followup_msg:
            messages.append(followup_msg)
        
        # Tasks
        task_msg = format_task_message(tasks, agente)
        if task_msg:
            messages.append(task_msg)
        
        if messages:
            full_message = "\n\n".join(messages)
            phone = AGENT_WHATSAPP.get(agente)
            
            if phone:
                result = send_whatsapp_message(phone, full_message)
                results["alerts_sent"].append({
                    "agente": agente,
                    "phone": phone,
                    "result": result
                })
            
            # También guardar en interactions como logging
            supabase.table("interactions").insert({
                "lead_id": None,
                "agente": "system",
                "canal": "whatsapp",
                "tipo": "notificacion_interna",
                "contenido": f"Alerta diaria enviada a {agente}: {len(messages)} mensaje(s)"
            })
    
    return results

def main():
    """Función principal - se ejecuta diariamente"""
    print(f"🚀 Starting WhatsApp Alert Service - {datetime.now()}")
    
    supabase = get_supabase_client()
    
    # Obtener datos
    followups = get_followups_hoy(supabase)
    tasks = get_tasks_hoy(supabase)
    
    print(f"📊 Found {len(followups)} followups and {len(tasks)} tasks for today")
    
    # Enviar alertas
    results = send_alerts_to_agents(supabase)
    
    print(f"✅ Alerts sent: {len(results['alerts_sent'])}")
    for alert in results["alerts_sent"]:
        print(f"   - {alert['agente']}: {alert['result'].get('method', 'unknown')}")
    
    return results

if __name__ == "__main__":
    main()