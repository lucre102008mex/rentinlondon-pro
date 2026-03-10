-- Migration to set up webhook for calendar_events
-- This requires pg_net extension to be enabled in Supabase

create trigger "calendar_events_telegram_webhook"
after insert on "public"."calendar_events"
for each row
execute function "supabase_functions"."http_request"(
  'http://localhost:54321/functions/v1/notify-telegram-event', -- Replace with production URL when deployed
  'POST',
  '{"Content-Type": "application/json"}',
  '{}',
  '1000'
);
