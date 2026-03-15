// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

interface CalendarEvent {
  id?: string;
  title: string;
  date: string;
  time?: string;
  category: string;
  description?: string;
  created_at?: string;
}

interface BookingRecord {
  id: string;
  lead_id: string;
  agente_asignado: string;
  fecha_cita: string;
  hora_cita: string;
  tipo: string;
  estado: string;
  notas?: string;
  reminder_24h_enviado: boolean;
  reminder_2h_enviado: boolean;
}

async function sendTelegramMessage(message: string, botToken: string, chatId: string): Promise<boolean> {
  const url = `https://api.telegram.org/bot${botToken}/sendMessage`;
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chat_id: chatId,
      text: message,
      parse_mode: "Markdown",
    }),
  });

  if (!response.ok) {
    console.error("Error from Telegram API:", await response.text());
    return false;
  }
  return true;
}

Deno.serve(async (req) => {
  try {
    const TELEGRAM_BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN");
    const TELEGRAM_CHAT_ID = Deno.env.get("TELEGRAM_CHAT_ID");

    if (!TELEGRAM_BOT_TOKEN || !TELEGRAM_CHAT_ID) {
      console.error("Missing Telegram credentials. Check environment variables.");
      return new Response("Missing configuration.", { status: 500 });
    }

    let payload: Record<string, unknown> = {};
    const contentType = req.headers.get("Content-Type") || "";

    if (contentType.includes("application/json")) {
      payload = await req.json();
    } else {
      return new Response("Invalid content type.", { status: 400 });
    }

    console.log("Received payload:", JSON.stringify(payload));

    // Handle Supabase trigger format: { type: "INSERT", table: "calendar_events", record: {...} }
    // Handle direct record format: { category: "booking", title: "...", ... }
    // Handle booking format from trigger

    const record = payload.record || payload as Record<string, unknown>;
    const category = (record.category || payload.type || "unknown") as string;

    // CALENDAR EVENTS (from calendar_events table)
    if (category === "calendar_events" || record.title) {
      const event = record as CalendarEvent;
      
      if (event.category === "booking" || event.title?.toLowerCase().includes("booking")) {
        // This is a booking notification
        const message = `
📅 *NUEVO BOOKING CONFIRMADO* 📅

🏢 *Cita:* ${event.date} a las ${event.time || "por confirmar"}
📝 *Detalles:* ${event.description || "Sin notas"}
        `.trim();

        const sent = await sendTelegramMessage(message, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID);
        if (!sent) {
          return new Response("Failed to send booking notification.", { status: 500 });
        }
        console.log("Booking notification sent successfully");
        return new Response("Booking notification sent.", { status: 200 });
      }

      // General calendar event
      const message = `
🔔 *Nuevo Evento en el Calendario* 🔔

📌 *Título:* ${event.title}
🗓️ *Fecha:* ${event.date}
⏰ *Hora:* ${event.time || "Todo el día"}
🏷️ *Categoría:* ${event.category?.toUpperCase() || "General"}
${event.description ? `\n📝 *Detalles:* ${event.description}` : ""}
      `.trim();

      const sent = await sendTelegramMessage(message, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID);
      if (!sent) {
        return new Response("Failed to send calendar notification.", { status: 500 });
      }
      return new Response("Calendar notification sent.", { status: 200 });
    }

    // Handle booking record directly (from booking INSERT trigger)
    if (record.fecha_cita && record.hora_cita) {
      const booking = record as BookingRecord;
      const message = `
📅 *NUEVO BOOKING CONFIRMADO* 📅

🗓️ *Fecha:* ${booking.fecha_cita}
⏰ *Hora:* ${booking.hora_cita}
👤 *Agente:* ${booking.agente_asignado}
🏷️ *Tipo:* ${booking.tipo}
📌 *Estado:* ${booking.estado}
${booking.notas ? `\n📝 *Notas:* ${booking.notas}` : ""}
      `.trim();

      const sent = await sendTelegramMessage(message, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID);
      if (!sent) {
        return new Response("Failed to send booking notification.", { status: 500 });
      }
      console.log("Booking notification sent successfully");
      return new Response("Booking notification sent.", { status: 200 });
    }

    // Handle REMINDER_24H
    if (payload.type === "REMINDER_24H") {
      const booking = record as { lead_name?: string; lead_telefono?: string; fecha_cita?: string; hora_cita?: string; tipo?: string; notas?: string };
      const message = `
⏰ *RECORDATORIO - 24 HORAS* ⏰

👤 *Lead:* ${booking.lead_name || "Desconocido"}
📱 *Teléfono:* ${booking.lead_telefono || "No disponible"}
🗓️ *Fecha:* ${booking.fecha_cita}
⏰ *Hora:* ${booking.hora_cita}
🏷️ *Tipo:* ${booking.tipo}
${booking.notas ? `\n📝 *Notas:* ${booking.notas}` : ""}
      `.trim();

      const sent = await sendTelegramMessage(message, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID);
      if (!sent) {
        return new Response("Failed to send reminder.", { status: 500 });
      }
      console.log("24h reminder sent successfully");
      return new Response("Reminder sent.", { status: 200 });
    }

    // Handle REMINDER_2H
    if (payload.type === "REMINDER_2H") {
      const booking = record as { lead_name?: string; lead_telefono?: string; fecha_cita?: string; hora_cita?: string; tipo?: string; notas?: string };
      const message = `
🔥 *URGENTE - RECORDATORIO EN 2 HORAS* 🔥

👤 *Lead:* ${booking.lead_name || "Desconocido"}
📱 *Teléfono:* ${booking.lead_telefono || "No disponible"}
🗓️ *Fecha:* ${booking.fecha_cita}
⏰ *Hora:* ${booking.hora_cita}
🏷️ *Tipo:* ${booking.tipo}
${booking.notas ? `\n📝 *Notas:* ${booking.notas}` : ""}
      `.trim();

      const sent = await sendTelegramMessage(message, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID);
      if (!sent) {
        return new Response("Failed to send reminder.", { status: 500 });
      }
      console.log("2h reminder sent successfully");
      return new Response("Reminder sent.", { status: 200 });
    }

    // Default response if not recognized
    console.log("Payload not recognized, skipping notification");
    return new Response("Webhook received but no notification sent.", { status: 200 });

  } catch (error) {
    console.error("Failed handling webhook:", error);
    return new Response("Internal Server Error", { status: 500 });
  }
})
