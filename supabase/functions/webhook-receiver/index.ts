// =============================================================================
// RentInLondon PRO — Edge Function: webhook-receiver
// Recibe webhooks firmados con HMAC SHA-256 desde OpenClaw y otros servicios
// =============================================================================

const WEBHOOK_HMAC_SECRET = Deno.env.get("WEBHOOK_HMAC_SECRET")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Tipos de eventos permitidos
const ALLOWED_EVENTS = new Set([
  "lead.created",
  "lead.updated",
  "lead.escalated",
  "interaction.logged",
  "viewing.scheduled",
  "viewing.completed",
  "contract.signed",
  "listing.refreshed",
  "agent.alert",
]);

// ─── Verificar firma HMAC SHA-256 ─────────────────────────────────────────────
async function verifyHmac(body: string, signature: string): Promise<boolean> {
  if (!signature) return false;

  const encoder = new TextEncoder();
  const keyData = encoder.encode(WEBHOOK_HMAC_SECRET);
  const messageData = encoder.encode(body);

  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  // Calcular firma esperada
  const signatureBuffer = await crypto.subtle.sign("HMAC", cryptoKey, messageData);
  const hashArray = Array.from(new Uint8Array(signatureBuffer));
  const expectedSig = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");

  // Extraer firma recibida
  const receivedSig = signature.replace(/^sha256=/, "");

  // Comparación timing-safe (evitar timing attacks)
  if (expectedSig.length !== receivedSig.length) return false;

  let diff = 0;
  for (let i = 0; i < expectedSig.length; i++) {
    diff |= expectedSig.charCodeAt(i) ^ receivedSig.charCodeAt(i);
  }
  return diff === 0;
}

// ─── Registrar evento en agent_logs ──────────────────────────────────────────
async function logEvent(event: string, payload: Record<string, unknown>, source: string): Promise<void> {
  const response = await fetch(
    `${SUPABASE_URL}/rest/v1/agent_logs`,
    {
      method: "POST",
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        "Content-Type": "application/json",
        Prefer: "return=minimal",
      },
      body: JSON.stringify({
        agente: source || "script-runner",
        accion: event,
        lead_id: payload.lead_id || null,
        property_id: payload.property_id || null,
        exito: true,
        metadata: { event, payload, received_at: new Date().toISOString() },
      }),
    }
  );

  if (!response.ok) {
    console.error(`Failed to log event: ${await response.text()}`);
  }
}

// ─── Handler principal ────────────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  // Health check
  if (req.method === "GET") {
    return new Response(
      JSON.stringify({ status: "ok", service: "webhook-receiver", timestamp: new Date().toISOString() }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const bodyText = await req.text();

  // Verificar HMAC
  const signature = req.headers.get("X-Signature") ||
                    req.headers.get("X-Hub-Signature-256") || "";
  const isValid = await verifyHmac(bodyText, signature);

  if (!isValid) {
    console.warn(`Invalid HMAC signature received. Sig: ${signature.substring(0, 20)}...`);
    return new Response(JSON.stringify({ error: "Unauthorized: Invalid signature" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(bodyText);
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const event = String(payload.event || "");
  const source = String(payload.source || "unknown");

  // Validar tipo de evento
  if (!ALLOWED_EVENTS.has(event)) {
    return new Response(
      JSON.stringify({ error: `Unknown event type: ${event}` }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  // Registrar en agent_logs
  await logEvent(event, payload, source);

  // Responder con éxito
  return new Response(
    JSON.stringify({
      received: true,
      event,
      source,
      processed_at: new Date().toISOString(),
    }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
});
