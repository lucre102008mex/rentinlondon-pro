import os, requests, json

# Configuración desde el entorno de OpenClaw
SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://tiwwthopkvtngpyhchbx.supabase.co")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") # Usamos Service Role para acceso total

if not SUPABASE_KEY:
    print("ERROR: SUPABASE_SERVICE_ROLE_KEY no encontrada en el .env")
    exit(1)

headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json"
}

def sync_table(table_name):
    print(f"Sincronizando tabla: {table_name}...")
    url = f"{SUPABASE_URL}/rest/v1/{table_name}?select=*"
    if table_name in ["leads", "bookings", "interactions"]:
        url += "&order=created_at.desc"
    res = requests.get(url, headers=headers)
    
    if res.status_code != 200:
        print(f"Error al sincronizar {table_name}: {res.text}")
        return

    data = res.json()
    filename = f"{table_name}.json"
    
    with open(filename, "w") as f:
        json.dump(data, f, indent=2)

    print(f"Hecho. Sincronizados {len(data)} registros en {filename}.")

if __name__ == "__main__":
    # Sincronizamos las tablas principales para darles contexto total
    tables = ["bookings", "leads", "properties", "interactions"]
    for table in tables:
        sync_table(table)
