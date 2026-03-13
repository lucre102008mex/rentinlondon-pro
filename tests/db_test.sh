#!/bin/bash
# =============================================================================
# script de Pruebas Automatizadas - RentInLondon PRO
# Verifica la lógica de triggers en Supabase
# =============================================================================

# Cargar variables de entorno
ENV_FILE="/Users/wilfredy/Ivylettings/rentinlondon-pro/openclaw/.env"
URL=$(grep "^SUPABASE_URL=" "$ENV_FILE" | head -n1 | cut -d'=' -f2)
KEY=$(grep "^SUPABASE_SERVICE_ROLE_KEY=" "$ENV_FILE" | head -n1 | cut -d'=' -f2)

if [ -z "$URL" ] || [ -z "$KEY" ]; then
    echo "❌ Error: Faltan credenciales de Supabase en openclaw/.env"
    exit 1
fi

echo "🚀 Iniciando pruebas de integración..."

# 1. Crear un Lead de prueba
echo "📝 Creando lead de prueba..."
LEAD_ID=$(curl -s -X POST "$URL/rest/v1/leads" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" -H "Prefer: return=minimal" \
  -d '{ "nombre": "Test Lead Automated", "telefono": "+44123", "canal_origen": "test", "scl_score": 5 }' \
  -w "%{header_json}" | grep -oP '"Location":\["\K[^"]+' | cut -d'=' -f2)

# Si el anterior falla (depende de la versión de curl/grep), intentar obtener el ID por búsqueda
LEAD_ID=$(curl -s -X GET "$URL/rest/v1/leads?nombre=eq.Test%20Lead%20Automated&select=id" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY" | grep -oP '"id":"\K[^"]+')

if [ -z "$LEAD_ID" ]; then
    echo "❌ Error al crear lead de prueba"
    exit 1
fi
echo "✅ Lead creado: $LEAD_ID"

# 2. Probar fn_create_booking
echo "📅 Probando fn_create_booking..."
RPC_DATA="{\"p_lead_id\": \"$LEAD_ID\", \"p_agente\": \"ivy\", \"p_fecha\": \"$(date +%Y-%m-%d)\", \"p_hora\": \"14:00\", \"p_notas\": \"Prueba de trigger\"}"

curl -s -X POST "$URL/rest/v1/rpc/fn_create_booking" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d "$RPC_DATA" > /dev/null

# Verificar estado del lead
STATUS=$(curl -s -X GET "$URL/rest/v1/leads?id=eq.$LEAD_ID&select=status" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY" | grep -oP '"status":"\K[^"]+')

if [ "$STATUS" == "viewing_programado" ]; then
    echo "✅ Trigger Viewing: OK (Status: $STATUS)"
else
    echo "❌ Trigger Viewing: FALLÓ (Status actual: $STATUS)"
fi

# 3. Probar fn_record_score_change
echo "📈 Probando fn_record_score_change..."
curl -s -X PATCH "$URL/rest/v1/leads?id=eq.$LEAD_ID" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{ "scl_score": 9 }'

# Verificar historial
HISTORY_COUNT=$(curl -s -X GET "$URL/rest/v1/lead_score_history?lead_id=eq.$LEAD_ID&select=count" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY" -H "Prefer: count=exact" | grep -oP '"count":\K\d+')

if [ "$HISTORY_COUNT" -gt 0 ]; then
    echo "✅ Trigger History: OK (Registros: $HISTORY_COUNT)"
else
    echo "❌ Trigger History: FALLÓ (No se encontró registro en historial)"
fi

# 4. Limpieza
echo "🧹 Limpiando datos de prueba..."
curl -s -X DELETE "$URL/rest/v1/leads?id=eq.$LEAD_ID" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY" > /dev/null

echo "🏁 Pruebas finalizadas."
