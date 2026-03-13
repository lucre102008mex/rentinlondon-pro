-- =============================================================================
-- Migración 00005: Bookings + Lead Followups
-- RentInLondon PRO
-- Agrega: bookings (citas oficina UK), lead_followups (seguimiento 15/7/3 días)
-- =============================================================================

-- ─── 1. TABLA: bookings ─────────────────────────────────────────────────────
-- Citas confirmadas en oficina 154 Bishopsgate (UK leads únicamente)
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
    agente_asignado TEXT NOT NULL CHECK (agente_asignado IN ('ivy','rose','salo','jeanette','human')),
    fecha_cita DATE NOT NULL,
    hora_cita TIME NOT NULL,
    tipo TEXT NOT NULL DEFAULT 'presencial' CHECK (tipo IN ('presencial','hibrido','video_tour')),
    estado TEXT NOT NULL DEFAULT 'programado' CHECK (estado IN ('programado','confirmado','completado','cancelado','no_show','reagendado')),
    notas TEXT,
    reminder_24h_enviado BOOLEAN DEFAULT FALSE,
    reminder_2h_enviado BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.bookings IS 'Citas confirmadas en oficina 154 Bishopsgate. Solo para leads UK que confirmaron presencial.';

CREATE INDEX IF NOT EXISTS idx_bookings_lead ON public.bookings (lead_id);
CREATE INDEX IF NOT EXISTS idx_bookings_fecha ON public.bookings (fecha_cita, hora_cita);
CREATE INDEX IF NOT EXISTS idx_bookings_agente_estado ON public.bookings (agente_asignado, estado);
CREATE INDEX IF NOT EXISTS idx_bookings_estado_fecha ON public.bookings (estado, fecha_cita);

-- Trigger updated_at
CREATE TRIGGER trg_bookings_updated_at
    BEFORE UPDATE ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_updated_at();

-- ─── 2. TABLA: lead_followups ───────────────────────────────────────────────
-- Sistema de seguimiento automático: 15, 7, y 3 días antes de fecha_mudanza
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.lead_followups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
    agente_asignado TEXT NOT NULL CHECK (agente_asignado IN ('ivy','rose','salo','jeanette','human')),
    fecha_mudanza_original DATE NOT NULL,
    dias_antes INTEGER NOT NULL CHECK (dias_antes IN (15, 7, 3)),
    fecha_seguimiento DATE NOT NULL,
    tipo_seguimiento TEXT NOT NULL DEFAULT 'recordatorio_mudanza' CHECK (tipo_seguimiento IN ('recordatorio_mudanza','follow_up_general','nurturing','recontacto_dormante')),
    estado TEXT NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente','contactado','confirmado','saltado','perdido',' reagendado')),
    resultado_contacto TEXT,
    notas TEXT,
    creado_automatico BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completado_at TIMESTAMPTZ
);

COMMENT ON TABLE public.lead_followups IS 'Seguimiento automático de leads. Se generan 3 recordatorios: 15, 7, y 3 días antes de fecha_mudanza.';

CREATE INDEX IF NOT EXISTS idx_followups_lead ON public.lead_followups (lead_id);
CREATE INDEX IF NOT EXISTS idx_followups_fecha_estado ON public.lead_followups (fecha_seguimiento, estado);
CREATE INDEX IF NOT EXISTS idx_followups_agente ON public.lead_followups (agente_asignado, estado);
CREATE INDEX IF NOT EXISTS idx_followups_pendientes_hoy ON public.lead_followups (fecha_seguimiento, estado) WHERE estado = 'pendiente';

-- ─── 3. FUNCIÓN: Crear followups automáticamente ───────────────────────────

CREATE OR REPLACE FUNCTION public.fn_create_followups_on_mudanza()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Si no hay fecha_mudanza, no crear followups
    IF NEW.fecha_mudanza IS NULL THEN
        RETURN NEW;
    END IF;

    -- Si la fecha ya pasó, no crear followups
    IF NEW.fecha_mudanza <= CURRENT_DATE THEN
        RETURN NEW;
    END IF;

    -- Eliminar followups pendientes anteriores (evitar duplicados)
    DELETE FROM public.lead_followups
    WHERE lead_id = NEW.id
    AND estado = 'pendiente';

    -- Crear 3 followups: 15, 7, y 3 días antes
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

COMMENT ON FUNCTION public.fn_create_followups_on_mudanza() IS 'Crea automáticamente 3 followups (15, 7, 3 días antes) cuando se establece fecha_mudanza en un lead.';

-- ─── 4. TRIGGER: Activar creación de followups ─────────────────────────────

DROP TRIGGER IF EXISTS trg_leads_create_followups ON public.leads;
CREATE TRIGGER trg_leads_create_followups
    AFTER INSERT OR UPDATE OF fecha_mudanza, asignado_a
    ON public.leads
    FOR EACH ROW
    WHEN (NEW.fecha_mudanza IS NOT NULL AND NEW.fecha_mudanza > CURRENT_DATE)
    EXECUTE FUNCTION public.fn_create_followups_on_mudanza();

-- ─── 5. VISTA: Followups pendientes para hoy ───────────────────────────────

CREATE OR REPLACE VIEW public.v_followups_hoy AS
SELECT
    f.id AS followup_id,
    l.id AS lead_id,
    l.nombre,
    l.telefono,
    l.email,
    l.canal_origen,
    l.zona_preferida,
    l.tipo_propiedad,
    l.presupuesto_max,
    l.fecha_mudanza,
    f.dias_antes,
    f.fecha_seguimiento,
    f.tipo_seguimiento,
    f.agente_asignado,
    l.scl_score,
    l.status AS lead_status,
    f.estado AS followup_estado,
    l.ultima_interaccion AT TIME ZONE 'Europe/London' AS ultima_interaccion_london,
    EXTRACT(DAY FROM (NOW() - l.ultima_interaccion))::INTEGER AS dias_sin_contacto
FROM public.lead_followups f
JOIN public.leads l ON f.lead_id = l.id
WHERE f.fecha_seguimiento = CURRENT_DATE
AND f.estado = 'pendiente'
ORDER BY
    f.dias_antes ASC,  -- Los de 3 días primero (más urgentes)
    l.scl_score DESC;

COMMENT ON VIEW public.v_followups_hoy IS 'Followups pendientes para hoy, ordenados por urgencia.';

-- ─── 6. VISTA: Todos los followups pendientes (próximos 30 días) ───────────

CREATE OR REPLACE VIEW public.v_followups_pendientes AS
SELECT
    f.id AS followup_id,
    l.id AS lead_id,
    l.nombre,
    l.telefono,
    l.canal_origen,
    l.zona_preferida,
    l.presupuesto_max,
    l.fecha_mudanza,
    f.dias_antes,
    f.fecha_seguimiento,
    f.agente_asignado,
    l.scl_score,
    l.status,
    f.estado,
    f.fecha_seguimiento - CURRENT_DATE AS dias_restantes
FROM public.lead_followups f
JOIN public.leads l ON f.lead_id = l.id
WHERE f.estado = 'pendiente'
AND f.fecha_seguimiento BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
ORDER BY f.fecha_seguimiento ASC, l.scl_score DESC;

-- ─── 7. VISTA: Bookings de hoy ─────────────────────────────────────────────

CREATE OR REPLACE VIEW public.v_bookings_hoy AS
SELECT
    b.id AS booking_id,
    l.id AS lead_id,
    l.nombre,
    l.telefono,
    l.canal_origen,
    l.zona_preferida,
    l.presupuesto_max,
    b.fecha_cita,
    b.hora_cita,
    b.tipo,
    b.estado,
    b.agente_asignado,
    b.notas,
    l.scl_score,
    b.reminder_24h_enviado,
    b.reminder_2h_enviado,
    l.es_internacional
FROM public.bookings b
JOIN public.leads l ON b.lead_id = l.id
WHERE b.fecha_cita = CURRENT_DATE
ORDER BY b.hora_cita ASC;

COMMENT ON VIEW public.v_bookings_hoy IS 'Bookings (citas en oficina) programados para hoy.';

-- ─── 8. VISTA: Todos los bookings activos ──────────────────────────────────

CREATE OR REPLACE VIEW public.v_bookings_activos AS
SELECT
    b.id AS booking_id,
    l.id AS lead_id,
    l.nombre,
    l.telefono,
    l.canal_origen,
    l.zona_preferida,
    l.presupuesto_max,
    b.fecha_cita,
    b.hora_cita,
    b.tipo,
    b.estado,
    b.agente_asignado,
    b.notas,
    l.scl_score,
    b.fecha_cita - CURRENT_DATE AS dias_para_cita
FROM public.bookings b
JOIN public.leads l ON b.lead_id = l.id
WHERE b.estado IN ('programado','confirmado')
AND b.fecha_cita >= CURRENT_DATE
ORDER BY b.fecha_cita ASC, b.hora_cita ASC;

-- ─── 9. VISTA: Dashboard de agente (resumen) ───────────────────────────────

CREATE OR REPLACE VIEW public.v_agente_dashboard AS
SELECT
    l.asignado_a AS agente,
    COUNT(*) FILTER (WHERE l.status NOT IN ('rechazado','perdido','contrato_firmado')) AS leads_activos,
    COUNT(*) FILTER (WHERE l.scl_score >= 7 AND l.status NOT IN ('rechazado','perdido','contrato_firmado')) AS leads_hot,
    COUNT(*) FILTER (WHERE l.scl_score BETWEEN 4 AND 6 AND l.status NOT IN ('rechazado','perdido','contrato_firmado')) AS leads_warm,
    (SELECT COUNT(*) FROM public.lead_followups f WHERE f.agente_asignado = l.asignado_a AND f.fecha_seguimiento = CURRENT_DATE AND f.estado = 'pendiente') AS followups_hoy,
    (SELECT COUNT(*) FROM public.bookings b WHERE b.agente_asignado = l.asignado_a AND b.fecha_cita = CURRENT_DATE AND b.estado IN ('programado','confirmado')) AS bookings_hoy,
    (SELECT COUNT(*) FROM public.bookings b WHERE b.agente_asignado = l.asignado_a AND b.fecha_cita > CURRENT_DATE AND b.estado IN ('programado','confirmado')) AS bookings_futuros
FROM public.leads l
WHERE l.asignado_a IN ('ivy','rose','salo','jeanette')
GROUP BY l.asignado_a;

-- ─── 10. Actualizar v_daily_summary ────────────────────────────────────────

DROP VIEW IF EXISTS public.v_daily_summary CASCADE;

CREATE VIEW public.v_daily_summary AS
SELECT
    (CURRENT_DATE AT TIME ZONE 'Europe/London')::DATE AS fecha_london,
    (SELECT COUNT(*) FROM public.leads WHERE created_at::DATE = CURRENT_DATE) AS leads_nuevos_hoy,
    (SELECT COUNT(*) FROM public.leads WHERE status NOT IN ('rechazado','perdido','contrato_firmado')) AS leads_activos_total,
    (SELECT COUNT(*) FROM public.leads WHERE scl_score >= 7 AND status NOT IN ('rechazado','perdido','contrato_firmado')) AS leads_hot,
    (SELECT COUNT(*) FROM public.leads WHERE scl_score BETWEEN 4 AND 6 AND status NOT IN ('rechazado','perdido','contrato_firmado')) AS leads_warm,
    (SELECT COUNT(*) FROM public.leads WHERE scl_score <= 3 AND status NOT IN ('rechazado','perdido','contrato_firmado')) AS leads_cold,
    (SELECT COUNT(*) FROM public.v_leads_dss_pendientes) AS leads_dss_pendientes,
    (SELECT COUNT(*) FROM public.leads WHERE es_internacional = TRUE AND status NOT IN ('rechazado','perdido','contrato_firmado')) AS leads_internacionales,
    (SELECT COUNT(*) FROM public.bookings WHERE fecha_cita = CURRENT_DATE) AS bookings_hoy,
    (SELECT COUNT(*) FROM public.viewings WHERE fecha_hora::DATE = CURRENT_DATE) AS viewings_hoy,
    (SELECT COUNT(*) FROM public.contracts WHERE estado = 'activo') AS contratos_activos,
    (SELECT COUNT(*) FROM public.properties WHERE estado IN ('available','void')) AS propiedades_void,
    (SELECT COUNT(*) FROM public.lead_followups WHERE fecha_seguimiento = CURRENT_DATE AND estado = 'pendiente') AS followups_pendientes_hoy,
    NOW() AT TIME ZONE 'Europe/London' AS generado_at_london;

-- ─── 11. RLS para bookings ─────────────────────────────────────────────────

ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role_bookings" ON public.bookings
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "ivy_bookings" ON public.bookings
    FOR ALL USING (auth.jwt() ->> 'agent_id' = 'ivy' AND agente_asignado = 'ivy');

CREATE POLICY "rose_bookings" ON public.bookings
    FOR ALL USING (auth.jwt() ->> 'agent_id' = 'rose' AND agente_asignado = 'rose');

CREATE POLICY "salo_bookings" ON public.bookings
    FOR ALL USING (auth.jwt() ->> 'agent_id' = 'salo' AND agente_asignado = 'salo');

CREATE POLICY "jeanette_bookings" ON public.bookings
    FOR ALL USING (auth.jwt() ->> 'agent_id' = 'jeanette');

CREATE POLICY "alex_read_bookings" ON public.bookings
    FOR SELECT USING (auth.jwt() ->> 'agent_id' = 'alex');

-- ─── 12. RLS para lead_followups ───────────────────────────────────────────

ALTER TABLE public.lead_followups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role_followups" ON public.lead_followups
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "ivy_followups" ON public.lead_followups
    FOR ALL USING (auth.jwt() ->> 'agent_id' = 'ivy' AND agente_asignado = 'ivy');

CREATE POLICY "rose_followups" ON public.lead_followups
    FOR ALL USING (auth.jwt() ->> 'agent_id' = 'rose' AND agente_asignado = 'rose');

CREATE POLICY "salo_followups" ON public.lead_followups
    FOR ALL USING (auth.jwt() ->> 'agent_id' = 'salo' AND agente_asignado = 'salo');

CREATE POLICY "jeanette_followups" ON public.lead_followups
    FOR ALL USING (auth.jwt() ->> 'agent_id' = 'jeanette' AND agente_asignado = 'jeanette');

CREATE POLICY "alex_read_followups" ON public.lead_followups
    FOR SELECT USING (auth.jwt() ->> 'agent_id' = 'alex');

-- ─── 13. Actualizar vista viewings para clarificar uso ─────────────────────

COMMENT ON TABLE public.viewings IS 'Video tours para leads internacionales. Solo manejados por Jeanette. Para citas en oficina UK, usar tabla bookings.';

-- ─── 14. Función para marcar followup como contactado ──────────────────────

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

-- ─── 15. Función para crear booking desde lead ─────────────────────────────

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

    -- Actualizar estado del lead
    UPDATE public.leads
    SET
        status = 'viewing_programado',
        pipeline_stage = 'viewing'
    WHERE id = p_lead_id;

    -- Cancelar followups pendientes (ya tiene cita)
    UPDATE public.lead_followups
    SET estado = 'saltado', notas = 'Lead confirmó booking'
    WHERE lead_id = p_lead_id AND estado = 'pendiente';

    RETURN v_booking_id;
END;
$$;

-- ─── 16. Trigger para eliminar followups cuando lead cambia de estado ─────

CREATE OR REPLACE FUNCTION public.fn_cancel_followups_on_booking()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Si el lead pasa a viewing_programado o contrato_firmado, cancelar followups
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

-- =============================================================================
-- FIN DE MIGRACIÓN
-- =============================================================================
