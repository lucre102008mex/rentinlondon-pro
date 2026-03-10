// =============================================================================
// RentInLondon PRO — Edge Function: sync-to-sheets
// Sincroniza datos de Supabase con Google Sheets via Sheets API v4
// JWT real con djwt RS256 + HMAC verification
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GOOGLE_SA_EMAIL = Deno.env.get("GOOGLE_SA_EMAIL")!;
const GOOGLE_SA_PRIVATE_KEY = Deno.env.get("GOOGLE_SA_PRIVATE_KEY")!;
const GOOGLE_SHEETS_ID = Deno.env.get("GOOGLE_SHEETS_ID")!;
const WEBHOOK_HMAC_SECRET = Deno.env.get("WEBHOOK_HMAC_SECRET")!;

const JWT_EXPIRY_SECONDS = 3600;

// Tablas permitidas para sincronización (whitelist)
const ALLOWED_TABLES = new Set([
  "leads",
  "interactions",
  "properties",
  "viewings",
  "contracts",
  "listings_history",
  "weekly_summaries",
]);

// Mapeo tabla → pestaña de Google Sheets
const TABLE_TO_SHEET: Record<string, string> = {
  leads: "Leads",
  interactions: "Prospects",
  properties: "Propiedades",
  viewings: "Bookings",
  contracts: "Contratos",
  listings_history: "Ads Report",
  weekly_summaries: "Weekly Summary",
};

// ─── Verificar firma HMAC SHA-256 ─────────────────────────────────────────────
async function verifyHmac(body: string, signature: string): Promise<boolean> {
  const encoder = new TextEncoder();
  const keyData = encoder.encode(WEBHOOK_HMAC_SECRET);
  const messageData = encoder.encode(body);

  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"]
  );

  // Extraer el hash hex de "sha256=XXXX"
  const expectedSig = signature.replace(/^sha256=/, "");
  const sigBytes = new Uint8Array(
    expectedSig.match(/.{1,2}/g)!.map((byte) => parseInt(byte, 16))
  );

  return await crypto.subtle.verify("HMAC", cryptoKey, sigBytes, messageData);
}

// ─── Generar JWT para Google OAuth2 (RS256) ───────────────────────────────────
async function getGoogleAccessToken(): Promise<string> {
  // Importar clave privada RSA
  const pemKey = GOOGLE_SA_PRIVATE_KEY.replace(/\\n/g, "\n");
  const pemBody = pemKey
    .replace("-----BEGIN RSA PRIVATE KEY-----", "")
    .replace("-----END RSA PRIVATE KEY-----", "")
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const keyBuffer = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBuffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  // Crear JWT claim set
  const payload = {
    iss: GOOGLE_SA_EMAIL,
    scope: "https://www.googleapis.com/auth/spreadsheets",
    aud: "https://oauth2.googleapis.com/token",
    exp: getNumericDate(JWT_EXPIRY_SECONDS),
    iat: getNumericDate(0),
  };

  // Firmar JWT con djwt
  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    payload,
    privateKey
  );

  // Intercambiar JWT por access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenResponse.ok) {
    const error = await tokenResponse.text();
    throw new Error(`Google OAuth2 token error: ${error}`);
  }

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

// ─── Sincronizar datos a Google Sheets ───────────────────────────────────────
async function syncToSheet(
  accessToken: string,
  sheetName: string,
  rows: Record<string, unknown>[]
): Promise<void> {
  if (rows.length === 0) return;

  // Preparar valores (primera fila = headers, resto = datos)
  const headers = Object.keys(rows[0]);
  const values = [
    headers,
    ...rows.map((row) =>
      headers.map((h) => {
        const val = row[h];
        if (val === null || val === undefined) return "";
        if (typeof val === "object") return JSON.stringify(val);
        return String(val);
      })
    ),
  ];

  const quotedSheetName = sheetName.includes(" ") ? `'${sheetName}'` : sheetName;
  const sheetsApiUrl = `https://sheets.googleapis.com/v4/spreadsheets/${GOOGLE_SHEETS_ID}/values/${encodeURIComponent(quotedSheetName)}!A1:ZZ`;

  const response = await fetch(`${sheetsApiUrl}?valueInputOption=RAW`, {
    method: "PUT",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      range: `${quotedSheetName}!A1:ZZ`,
      majorDimension: "ROWS",
      values,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Google Sheets API error for ${sheetName}: ${error}`);
  }
}

// ─── Handler principal ────────────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  // Solo POST
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const bodyText = await req.text();

  // Verificar HMAC
  const signature = req.headers.get("X-Signature") || "";
  const isValid = await verifyHmac(bodyText, signature);
  if (!isValid) {
    return new Response(JSON.stringify({ error: "Invalid HMAC signature" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  let payload: { table?: string; ids?: string[] };
  try {
    payload = JSON.parse(bodyText);
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { table, ids } = payload;

  // Validar tabla (whitelist)
  if (!table || !ALLOWED_TABLES.has(table)) {
    return new Response(
      JSON.stringify({ error: `Table '${table}' not in sync whitelist` }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  const sheetName = TABLE_TO_SHEET[table];

  try {
    // Crear cliente Supabase con service role
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Consultar datos
    let query = supabase.from(table).select("*").order("created_at", { ascending: false }).limit(1000);

    if (ids && ids.length > 0) {
      query = supabase.from(table).select("*").in("id", ids);
    }

    const { data, error } = await query;
    if (error) throw new Error(`Supabase query error: ${error.message}`);

    // Obtener token de Google
    const accessToken = await getGoogleAccessToken();

    // Sincronizar
    await syncToSheet(accessToken, sheetName, data || []);

    return new Response(
      JSON.stringify({
        success: true,
        table,
        sheet: sheetName,
        rows_synced: data?.length || 0,
        synced_at: new Date().toISOString(),
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    console.error(`sync-to-sheets error: ${message}`);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
