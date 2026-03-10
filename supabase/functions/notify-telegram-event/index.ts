// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

Deno.serve(async (req) => {
  try {
    const TELEGRAM_BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN");
    const TELEGRAM_CHAT_ID = Deno.env.get("TELEGRAM_CHAT_ID");

    if (!TELEGRAM_BOT_TOKEN || !TELEGRAM_CHAT_ID) {
      console.error("Missing Telegram credentials. Check environment variables.");
      return new Response("Missing configuration.", { status: 500 });
    }

    const payload = await req.json();
    
    // Check if it's an INSERT trigger payload on calendar_events
    if (payload.type === "INSERT" && payload.table === "calendar_events") {
      const record = payload.record;

      // Construct visually appealing Telegram message
      const message = `
🔔 *Nuevo Evento en el Calendario* 🔔

📌 *Título:* ${record.title}
🗓️ *Fecha:* ${record.date}
⏰ *Hora:* ${record.time || "Todo el día"}
🏷️ *Categoría:* ${record.category?.toUpperCase() || "General"}
${record.description ? `\n📝 *Detalles:* ${record.description}` : ""}
      `.trim();

      const url = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`;
      const response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          chat_id: TELEGRAM_CHAT_ID,
          text: message,
          parse_mode: "Markdown",
        }),
      });

      if (!response.ok) {
        console.error("Error from Telegram API:", await response.text());
        return new Response("Failed to send telegram message.", { status: 500 });
      }

      return new Response("Notification sent successfully.", { status: 200 });
    }

    // Default response if not the target webhook payload
    return new Response("Webhook received.", { status: 200 });

  } catch (error) {
    console.error("Failed handling webhook:", error);
    return new Response("Internal Server Error", { status: 500 });
  }
})
