
import csv
import re

def normalize_phone(phone):
    if not phone: return ""
    return re.sub(r'\D', '', str(phone))

# Load existing phones
with open('/Users/wilfredy/Ivylettings/rentinlondon-pro/db_phones.txt', 'r') as f:
    db_phones = set(normalize_phone(line.strip()) for line in f if line.strip())

# Load candidates from CSV
candidates = []
with open('/Users/wilfredy/Ivylettings/rentinlondon-pro/leads_frios.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        name = row.get('Full Name', '').strip()
        phone = row.get('Phone', '').strip()
        if name and phone:
            candidates.append({'nombre': name, 'telefono': phone})

# Identify new leads
new_leads = []
seen_in_import = set()

for lead in candidates:
    norm = normalize_phone(lead['telefono'])
    if norm and norm not in db_phones and norm not in seen_in_import:
        new_leads.append(lead)
        seen_in_import.add(norm)

# Generate SQL in batches of 100
if not new_leads:
    print("No new leads found.")
else:
    sql_batches = []
    batch_size = 100
    for i in range(0, len(new_leads), batch_size):
        batch = new_leads[i:i + batch_size]
        sql = "INSERT INTO public.leads (nombre, telefono, status, canal_origen, asignado_a) VALUES\n"
        values = []
        for l in batch:
            name = l['nombre'].replace("'", "''")
            phone = l['telefono'].replace("'", "''")
            values.append(f"('{name}', '{phone}', 'dormido', 'whatsapp', 'ivy')")
        sql += ",\n".join(values) + ";"
        sql_batches.append(sql)
    
    with open('/Users/wilfredy/Ivylettings/rentinlondon-pro/import_missing_leads.sql', 'w') as f:
        f.write("\n\n".join(sql_batches))
    
    print(f"Parsed {len(candidates)} candidates.")
    print(f"Found {len(new_leads)} new leads.")
    print(f"SQL written to import_missing_leads.sql in {len(sql_batches)} batches.")
