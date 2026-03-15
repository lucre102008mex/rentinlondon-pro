-- =============================================================================
-- Migración: Fix booking notifications + Reminders
-- RentInLondon PRO
--解决的问题:
-- 1. Notificaciones de Telegram al crear booking
-- 2. Recordatorios 24h y 2h antes del booking
-- =============================================================================

-- ─── 1. FUNCIÓN: Notificar Telegram directamente desde booking ───────────────
-- Esta función se dispara cuando se crea un booking y envía notificación a Telegram

CREATE OR REPLACE FUNCTION public.fn_notify_booking_telegram()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    lead_name TEXT;
    lead_telefono TEXT;
    message TEXT;
    webhook_url TEXT := 'https://tiwwthopkvtngpyhchbx.supabase.co/functions/v1/notify-telegram-event';
BEGIN
    -- Obtener datos del lead
    SELECT nombre, telefono INTO lead_name, lead_telefono
    FROM public.leads
    WHERE id = NEW.lead_id;

    -- Construir mensaje
    message := json_build_object(
        'type', 'INSERT',
        'table', 'bookings',
        'record', json_build_object(
            'id', NEW.id,
            'lead_id', NEW.lead_id,
            'agente_asignado', NEW.agente_asignado,
            'fecha_cita', NEW.fecha_cita,
            'hora_cita', NEW.hora_cita,
            'tipo', NEW.tipo,
            'estado', NEW.estado,
            'notas', NEW.notas,
            'lead_name', lead_name,
            'lead_telefono', lead_telefono
        )
    )::text;

    -- Enviar notificación via pg_net (si está disponible)
    PERFORM supabase_functions.http_request(
        webhook_url,
        'POST',
        '{"Content-Type": "application/json"}',
        message,
        '10000'
    );

    RETURN NEW;
END;
$$;

-- Trigger para notifications de bookings
DROP TRIGGER IF EXISTS trg_bookings_notify_telegram ON public.bookings;
CREATE TRIGGER trg_bookings_notify_telegram
    AFTER INSERT ON public.bookings
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_notify_booking_telegram();

-- ─── 2. FUNCIÓN: Enviar recordatorios 24h y 2h antes del booking ─────────────

CREATE OR REPLACE FUNCTION public.fn_send_booking_reminders()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    booking_record RECORD;
    lead_name TEXT;
    lead_telefono TEXT;
    message TEXT;
    webhook_url TEXT := 'https://tiwwthopkvtngpyhchbx.supabase.co/functions/v1/notify-telegram-event';
    current_time TIMESTAMPTZ := NOW() AT TIME ZONE 'Europe/London';
    two_hours_later TIMESTAMPTZ;
    twenty_four_hours_later TIMESTAMPTZ;
BEGIN
    two_hours_later := current_time + INTERVAL '2 hours';
    twenty_four_hours_later := current_time + INTERVAL '24 hours';

    -- Recordatorios 24h antes
    FOR booking_record IN
        SELECT b.*, l.nombre, l.telefono
        FROM public.bookings b
        JOIN public.leads l ON b.lead_id = l.id
        WHERE b.estado IN ('programado', 'confirmado')
        AND b.reminder_24h_enviado = FALSE
        AND b.fecha_cita - current_time::DATE <= 1
        AND b.fecha_cita - current_time::DATE > 0
    LOOP
        message := json_build_object(
            'type', 'REMINDER_24H',
            'table', 'bookings',
            'record', json_build_object(
                'id', booking_record.id,
                'lead_name', booking_record.nombre,
                'lead_telefono', booking_record.telefono,
                'agente_asignado', booking_record.agente_asignado,
                'fecha_cita', booking_record.fecha_cita,
                'hora_cita', booking_record.hora_cita,
                'tipo', booking_record.tipo,
                'notas', booking_record.notas
            )
        )::text;

        PERFORM supabase_functions.http_request(
            webhook_url,
            'POST',
            '{"Content-Type": "application/json"}',
            message,
            '10000'
        );

        UPDATE public.bookings
        SET reminder_24h_enviado = TRUE
        WHERE id = booking_record.id;

        RAISE NOTICE 'Reminder 24h enviado para booking %', booking_record.id;
    END LOOP;

    -- Recordatorios 2h antes
    FOR booking_record IN
        SELECT b.*, l.nombre, l.telefono
        FROM public.bookings b
        JOIN public.leads l ON b.lead_id = l.id
        WHERE b.estado IN ('programado', 'confirmado')
        AND b.reminder_2h_enviado = FALSE
        AND (b.fecha_cita || ' ' || b.hora_cita)::TIMESTAMPTZ BETWEEN current_time AND two_hours_later
    LOOP
        message := json_build_object(
            'type', 'REMINDER_2H',
            'table', 'bookings',
            'record', json_build_object(
                'id', booking_record.id,
                'lead_name', booking_record.nombre,
                'lead_telefono', booking_record.telefono,
                'agente_asignado', booking_record.agente_asignado,
                'fecha_cita', booking_record.fecha_cita,
                'hora_cita', booking_record.hora_cita,
                'tipo', booking_record.tipo,
                'notas', booking_record.notas
            )
        )::text;

        PERFORM supabase_functions.http_request(
            webhook_url,
            'POST',
            '{"Content-Type": "application/json"}',
            message,
            '10000'
        );

        UPDATE public.bookings
        SET reminder_2h_enviado = TRUE
        WHERE id = booking_record.id;

        RAISE NOTICE 'Reminder 2h enviado para booking %', booking_record.id;
    END LOOP;
END;
$$;

-- ─── 3. CREAR TRIGGER para ejecutar recordatorios ───────────────────────────
-- Ejecutar cada hora usando pg_cron (si está disponible)
-- Esta es una alternativa: crear un trigger que se ejecute al actualizar cualquier booking

-- Función auxiliar para verificar y enviar recordatorios pendientes
CREATE OR REPLACE FUNCTION public.fn_check_and_send_reminders()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    current_time TIMESTAMPTZ := NOW() AT TIME ZONE 'Europe/London';
    booking_time TIMESTAMPTZ;
    lead_name TEXT;
    lead_telefono TEXT;
    message TEXT;
    webhook_url TEXT := 'https://tiwwthopkvtngpyhchbx.supabase.co/functions/v1/notify-telegram-event';
BEGIN
    -- Solo procesar si el booking está en estado válido
    IF NEW.estado NOT IN ('programado', 'confirmado') THEN
        RETURN NEW;
    END IF;

    -- Obtener datos del lead
    SELECT nombre, telefono INTO lead_name, lead_telefono
    FROM public.leads
    WHERE id = NEW.lead_id;

    booking_time := (NEW.fecha_cita || ' ' || COALESCE(NEW.hora_cita, '00:00:00'))::TIMESTAMPTZ;

    -- Verificar si es hora del recordatorio 24h (entre 23 y 24 horas antes)
    IF NEW.reminder_24h_enviado = FALSE 
       AND booking_time - current_time <= INTERVAL '24 hours'
       AND booking_time - current_time > INTERVAL '23 hours' THEN
        
        message := json_build_object(
            'type', 'REMINDER_24H',
            'record', json_build_object(
                'id', NEW.id,
                'lead_name', lead_name,
                'lead_telefono', lead_telefono,
                'agente_asignado', NEW.agente_asignado,
                'fecha_cita', NEW.fecha_cita,
                'hora_cita', NEW.hora_cita,
                'tipo', NEW.tipo,
                'notas', NEW.notas
            )
        )::text;

        PERFORM supabase_functions.http_request(
            webhook_url, 'POST',
            '{"Content-Type": "application/json"}',
            message, '10000'
        );

        NEW.reminder_24h_enviado := TRUE;
        RAISE NOTICE 'Reminder 24h enviado para booking %', NEW.id;
    END IF;

    -- Verificar si es hora del recordatorio 2h (entre 1.5 y 2.5 horas antes)
    IF NEW.reminder_2h_enviado = FALSE 
       AND booking_time - current_time <= INTERVAL '2 hours'
       AND booking_time - current_time > INTERVAL '1 hour' THEN
        
        message := json_build_object(
            'type', 'REMINDER_2H',
            'record', json_build_object(
                'id', NEW.id,
                'lead_name', lead_name,
                'lead_telefono', lead_telefono,
                'agente_asignado', NEW.agente_asignado,
                'fecha_cita', NEW.fecha_cita,
                'hora_cita', NEW.hora_cita,
                'tipo', NEW.tipo,
                'notas', NEW.notas
            )
        )::text;

        PERFORM supabase_functions.http_request(
            webhook_url, 'POST',
            '{"Content-Type": "application/json"}',
            message, '10000'
        );

        NEW.reminder_2h_enviado := TRUE;
        RAISE NOTICE 'Reminder 2h enviado para booking %', NEW.id;
    END IF;

    RETURN NEW;
END;
$$;

-- Trigger para enviar recordatorios al actualizar booking
DROP TRIGGER IF EXISTS trg_booking_send_reminders ON public.bookings;
CREATE TRIGGER trg_booking_send_reminders
    BEFORE UPDATE ON public.bookings
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_check_and_send_reminders();

-- ─── 4. Agregar handling de recordatorios a la función de Telegram ──────────
-- (Ya actualizado en notify-telegram-event/index.ts)

-- ─── 5. Permisos RLS actualizados ──────────────────────────────────────────

GRANT EXECUTE ON FUNCTION public.fn_send_booking_reminders TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_check_and_send_reminders TO service_role;

-- =============================================================================
-- FIN DE MIGRACIÓN
-- =============================================================================
