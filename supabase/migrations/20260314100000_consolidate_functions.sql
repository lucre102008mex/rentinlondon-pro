-- =============================================================================
-- Migración 20260314100000: Consolidar funciones duplicadas
-- =============================================================================

-- -------------------------------------------------------------------------
-- Eliminar versiones anteriores (pueden existir en migraciones pasadas)
-- -------------------------------------------------------------------------
-- DROP FUNCTION IF EXISTS public.fn_create_followups_on_mudanza(); -- commented to avoid dependency error
DROP FUNCTION IF EXISTS public.fn_create_booking(p_lead_id UUID, p_agente TEXT,
                                                 p_fecha DATE, p_hora TIME,
                                                 p_tipo TEXT, p_notas TEXT);
DROP FUNCTION IF EXISTS public.fn_record_score_change();
DROP FUNCTION IF EXISTS public.fn_archive_lead(p_lead_id UUID, p_motivo TEXT);
DROP FUNCTION IF EXISTS public.fn_get_agent_for_followup(p_lead_id UUID);
DROP FUNCTION IF EXISTS public.fn_reassign_followups_on_agent_change();

-- -------------------------------------------------------------------------
-- 1️⃣ fn_create_followups_on_mudanza (versión final con lógica de especialización)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_create_followups_on_mudanza()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_agente_asignado TEXT;
BEGIN
    IF NEW.fecha_mudanza IS NULL THEN RETURN NEW; END IF;
    IF NEW.fecha_mudanza <= CURRENT_DATE THEN RETURN NEW; END IF;

    -- Lógica de especialización
    IF NEW.es_internacional = TRUE THEN
        v_agente_asignado := 'jeanette';
    ELSIF NEW.escalado_jeanette = TRUE THEN
        v_agente_asignado := 'jeanette';
    ELSIF NEW.es_dss = TRUE AND NEW.dss_requisitos_cumplidos = FALSE THEN
        v_agente_asignado := 'jeanette';
    ELSE
        v_agente_asignado := COALESCE(NEW.asignado_a, 'ivy');
    END IF;

    DELETE FROM public.lead_followups
    WHERE lead_id = NEW.id AND estado = 'pendiente';

    INSERT INTO public.lead_followups
        (lead_id, agente_asignado, fecha_mudanza_original,
         dias_antes, fecha_seguimiento, tipo_seguimiento)
    VALUES
        (NEW.id, v_agente_asignado, NEW.fecha_mudanza, 15,
         NEW.fecha_mudanza - INTERVAL '15 days', 'recordatorio_mudanza'),
        (NEW.id, v_agente_asignado, NEW.fecha_mudanza, 7,
         NEW.fecha_mudanza - INTERVAL '7 days',  'recordatorio_mudanza'),
        (NEW.id, v_agente_asignado, NEW.fecha_mudanza, 3,
         NEW.fecha_mudanza - INTERVAL '3 days',  'recordatorio_mudanza')
    ON CONFLICT DO NOTHING;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_create_followups_on_mudanza IS
'Genera automáticamente los 3 follow‑ups (15, 7 y 3 días) usando la lógica de especialización:
 • Internacional → Jeanette
 • Escalado a Jeanette → Jeanette
 • DSS sin requisitos → Jeanette
 • Resto → agente asignado.';

-- -------------------------------------------------------------------------
-- 2️⃣ fn_create_booking (versión final)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_create_booking(
    p_lead_id UUID,
    p_agente TEXT,
    p_fecha DATE,
    p_hora TIME,
    p_tipo TEXT DEFAULT 'presencial',
    p_notas TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql AS $$
DECLARE v_booking_id UUID;
BEGIN
    INSERT INTO public.bookings
        (lead_id, agente_asignado, fecha_cita, hora_cita, tipo, notas)
    VALUES
        (p_lead_id, p_agente, p_fecha, p_hora, p_tipo, p_notas)
    RETURNING id INTO v_booking_id;

    UPDATE public.leads
    SET status = 'viewing_programado',
        pipeline_stage = 'viewing'
    WHERE id = p_lead_id;

    UPDATE public.lead_followups
    SET estado = 'saltado', notas = 'Lead confirmó booking'
    WHERE lead_id = p_lead_id AND estado = 'pendiente';

    RETURN v_booking_id;
END;
$$;

COMMENT ON FUNCTION public.fn_create_booking IS
'Crea un booking y actualiza el estado del lead a “viewing_programado”.';

-- -------------------------------------------------------------------------
-- 3️⃣ fn_record_score_change (versión final)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_record_score_change()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.scl_score IS DISTINCT FROM OLD.scl_score THEN
        INSERT INTO public.lead_score_history
            (lead_id, scl_score_anterior, scl_score_nuevo,
             cambio_score, factor_cambio, detalle_cambio)
        VALUES
            (NEW.id, OLD.scl_score, NEW.scl_score,
             COALESCE(NEW.scl_score,0)-COALESCE(OLD.scl_score,0),
             'auto',
             jsonb_build_object(
                 'urgency_score', NEW.urgency_score,
                 'data_completeness', NEW.data_completeness,
                 'budget_fit', NEW.budget_fit,
                 'wab_engagement_count', NEW.wab_engagement_count));
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_record_score_change IS
'Guarda historial de cambios de SCL score.';

-- -------------------------------------------------------------------------
-- 4️⃣ fn_archive_lead (para “archivar” sin borrar)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_archive_lead(p_lead_id UUID, p_motivo TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE public.leads
    SET pipeline_stage = 'lost',
        status = 'perdido',
        notas = COALESCE(notas, '') || E'\n[ARCHIVADO]: ' || p_motivo,
        updated_at = NOW()
    WHERE id = p_lead_id;
END;
$$;

COMMENT ON FUNCTION public.fn_archive_lead IS
'Archiva un lead cambiando su pipeline a “lost” y añadiendo una nota de motivo.';

-- -------------------------------------------------------------------------
-- 5️⃣ fn_get_agent_for_followup (utilidad)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_get_agent_for_followup(p_lead_id UUID)
RETURNS TEXT
LANGUAGE plpgsql AS $$
DECLARE v_lead RECORD; v_agente TEXT;
BEGIN
    SELECT * INTO v_lead FROM public.leads WHERE id = p_lead_id;
    IF NOT FOUND THEN RETURN 'ivy'; END IF;

    IF v_lead.es_internacional = TRUE THEN
        v_agente := 'jeanette';
    ELSIF v_lead.escalado_jeanette = TRUE THEN
        v_agente := 'jeanette';
    ELSIF v_lead.es_dss = TRUE AND v_lead.dss_requisitos_cumplidos = FALSE THEN
        v_agente := 'jeanette';
    ELSE
        v_agente := COALESCE(v_lead.asignado_a, 'ivy');
    END IF;
    RETURN v_agente;
END;
$$;

COMMENT ON FUNCTION public.fn_get_agent_for_followup IS
'Devuelve el agente correcto según especialización del lead.';

-- -------------------------------------------------------------------------
-- 6️⃣ fn_reassign_followups_on_agent_change (versión final)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_reassign_followups_on_agent_change()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE v_nuevos_followups INTEGER;
BEGIN
    IF OLD.asignado_a IS DISTINCT FROM NEW.asignado_a
       OR OLD.es_internacional IS DISTINCT FROM NEW.es_internacional
       OR OLD.escalado_jeanette IS DISTINCT FROM NEW.escalado_jeanette
       OR OLD.es_dss IS DISTINCT FROM NEW.es_dss
       OR OLD.dss_requisitos_cumplidos IS DISTINCT FROM NEW.dss_requisitos_cumplidos
    THEN
        IF NEW.es_internacional = TRUE THEN
            UPDATE public.lead_followups
            SET agente_asignado = 'jeanette',
                notas = COALESCE(notas,'') || ' | Reasignado: lead internacional'
            WHERE lead_id = NEW.id AND estado = 'pendiente' AND agente_asignado <> 'jeanette';
        ELSIF NEW.escalado_jeanette = TRUE THEN
            UPDATE public.lead_followups
            SET agente_asignado = 'jeanette',
                notas = COALESCE(notas,'') || ' | Reasignado: escalado a Jeanette'
            WHERE lead_id = NEW.id AND estado = 'pendiente' AND agente_asignado <> 'jeanette';
        ELSIF NEW.es_dss = TRUE AND NEW.dss_requisitos_cumplidos = FALSE THEN
            UPDATE public.lead_followups
            SET agente_asignado = 'jeanette',
                notas = COALESCE(notas,'') || ' | Reasignado: DSS sin requisitos'
            WHERE lead_id = NEW.id AND estado = 'pendiente' AND agente_asignado <> 'jeanette';
        END IF;
        GET DIAGNOSTICS v_nuevos_followups = ROW_COUNT;
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_reassign_followups_on_agent_change IS
'Reasigna automáticamente los follow‑ups pendientes cuando cambian las
condiciones de especialización del lead.';
