-- =============================================================================
-- Migración 00005b: Aplicar funciones y triggers faltantes
-- =============================================================================

-- 1. Función para crear followups automáticamente
CREATE OR REPLACE FUNCTION public.fn_create_followups_on_mudanza()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.fecha_mudanza IS NULL THEN
        RETURN NEW;
    END IF;

    IF NEW.fecha_mudanza <= CURRENT_DATE THEN
        RETURN NEW;
    END IF;

    DELETE FROM public.lead_followups
    WHERE lead_id = NEW.id
    AND estado = 'pendiente';

    INSERT INTO public.lead_followups
        (lead_id, agente_asignado, fecha_mudanza_original, dias_antes, fecha_seguimiento, tipo_seguimiento)
    VALUES
        (NEW.id, NEW.asignado_a, NEW.fecha_mudanza, 15, NEW.fecha_mudanza - INTERVAL '15 days', 'recordatorio_mudanza'),
        (NEW.id, NEW.asignado_a, NEW.fecha_mudanza, 7, NEW.fecha_mudanza - INTERVAL '7 days', 'recordatorio_mudanza'),
        (NEW.id, NEW.asignado_a, NEW.fecha_mudanza, 3, NEW.fecha_mudanza - INTERVAL '3 days', 'recordatorio_mudanza')
    ON CONFLICT DO NOTHING;

    RETURN NEW;
END;
$$;

-- 2. Trigger para activar creación de followups
DROP TRIGGER IF EXISTS trg_leads_create_followups ON public.leads;
CREATE TRIGGER trg_leads_create_followups
    AFTER INSERT OR UPDATE OF fecha_mudanza, asignado_a
    ON public.leads
    FOR EACH ROW
    WHEN (NEW.fecha_mudanza IS NOT NULL AND NEW.fecha_mudanza > CURRENT_DATE)
    EXECUTE FUNCTION public.fn_create_followups_on_mudanza();

-- 3. Función para cancelar followups cuando lead tiene booking
CREATE OR REPLACE FUNCTION public.fn_cancel_followups_on_booking()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status IN ('viewing_programado', 'contrato_firmado') THEN
        UPDATE public.lead_followups
        SET estado = 'saltado',
            notas = 'Cancelado automáticamente: lead status cambió a ' || NEW.status
        WHERE lead_id = NEW.id AND estado = 'pendiente';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_leads_cancel_followups ON public.leads;
CREATE TRIGGER trg_leads_cancel_followups
    AFTER UPDATE OF status ON public.leads
    FOR EACH ROW
    WHEN (NEW.status IN ('viewing_programado', 'contrato_firmado'))
    EXECUTE FUNCTION public.fn_cancel_followups_on_booking();

-- 4. Función para marcar followup como contactado
CREATE OR REPLACE FUNCTION public.fn_mark_followup_contactado(
    p_followup_id UUID,
    p_resultado TEXT DEFAULT NULL,
    p_notas TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.lead_followups
    SET
        estado = 'contactado',
        resultado_contacto = COALESCE(p_resultado, resultado_contacto),
        notas = COALESCE(p_notas, notas),
        completado_at = NOW()
    WHERE id = p_followup_id;
END;
$$;

-- 5. Función para crear booking desde lead
CREATE OR REPLACE FUNCTION public.fn_create_booking(
    p_lead_id UUID,
    p_agente TEXT,
    p_fecha DATE,
    p_hora TIME,
    p_tipo TEXT DEFAULT 'presencial',
    p_notas TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_booking_id UUID;
BEGIN
    INSERT INTO public.bookings
        (lead_id, agente_asignado, fecha_cita, hora_cita, tipo, notas)
    VALUES
        (p_lead_id, p_agente, p_fecha, p_hora, p_tipo, p_notas)
    RETURNING id INTO v_booking_id;

    UPDATE public.leads
    SET
        status = 'viewing_programado',
        pipeline_stage = 'viewing'
    WHERE id = p_lead_id;

    UPDATE public.lead_followups
    SET estado = 'saltado', notas = 'Lead confirmó booking'
    WHERE lead_id = p_lead_id AND estado = 'pendiente';

    RETURN v_booking_id;
END;
$$;

-- 6. Crear followups para leads existentes con fecha_mudanza futura
INSERT INTO public.lead_followups
    (lead_id, agente_asignado, fecha_mudanza_original, dias_antes, fecha_seguimiento, tipo_seguimiento)
SELECT 
    l.id,
    COALESCE(l.asignado_a, 'ivy'),
    l.fecha_mudanza,
    15,
    l.fecha_mudanza - INTERVAL '15 days',
    'recordatorio_mudanza'
FROM public.leads l
WHERE l.fecha_mudanza IS NOT NULL 
AND l.fecha_mudanza > CURRENT_DATE
AND NOT EXISTS (
    SELECT 1 FROM public.lead_followups f 
    WHERE f.lead_id = l.id AND f.dias_antes = 15 AND f.estado = 'pendiente'
);

INSERT INTO public.lead_followups
    (lead_id, agente_asignado, fecha_mudanza_original, dias_antes, fecha_seguimiento, tipo_seguimiento)
SELECT 
    l.id,
    COALESCE(l.asignado_a, 'ivy'),
    l.fecha_mudanza,
    7,
    l.fecha_mudanza - INTERVAL '7 days',
    'recordatorio_mudanza'
FROM public.leads l
WHERE l.fecha_mudanza IS NOT NULL 
AND l.fecha_mudanza > CURRENT_DATE
AND NOT EXISTS (
    SELECT 1 FROM public.lead_followups f 
    WHERE f.lead_id = l.id AND f.dias_antes = 7 AND f.estado = 'pendiente'
);

INSERT INTO public.lead_followups
    (lead_id, agente_asignado, fecha_mudanza_original, dias_antes, fecha_seguimiento, tipo_seguimiento)
SELECT 
    l.id,
    COALESCE(l.asignado_a, 'ivy'),
    l.fecha_mudanza,
    3,
    l.fecha_mudanza - INTERVAL '3 days',
    'recordatorio_mudanza'
FROM public.leads l
WHERE l.fecha_mudanza IS NOT NULL 
AND l.fecha_mudanza > CURRENT_DATE
AND NOT EXISTS (
    SELECT 1 FROM public.lead_followups f 
    WHERE f.lead_id = l.id AND f.dias_antes = 3 AND f.estado = 'pendiente'
);