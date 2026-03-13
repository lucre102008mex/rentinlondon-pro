-- =============================================================================
-- Migración 00006: Lead Score History + Lead Tasks
-- RentInLondon PRO
-- Agrega: historial de scoring, tabla de tareas/actividades
-- =============================================================================

-- ─── 1. TABLA: lead_score_history ───────────────────────────────────────────
-- Historial de cambios del SCL score para análisis y auditoría
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.lead_score_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
    scl_score_anterior SMALLINT,
    scl_score_nuevo SMALLINT NOT NULL,
    cambio_score INTEGER NOT NULL,  -- diferencia (positivo o negativo)
    factor_cambio TEXT,  -- qué causou el cambio: 'urgency', 'budget_fit', 'data_completeness', 'engagement', 'manual'
    detalle_cambio JSONB DEFAULT '{}'::JSONB,  -- datos adicionales del cambio
    agente_responsable TEXT,  -- quién hizo el cambio (si aplica)
    notas TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.lead_score_history IS 'Historial de cambios del SCL score. Permite analizar evolución del lead.';

CREATE INDEX IF NOT EXISTS idx_score_history_lead ON public.lead_score_history (lead_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_score_history_fecha ON public.lead_score_history (created_at DESC);

-- ─── 2. TABLA: lead_tasks ───────────────────────────────────────────────────
-- Tareas y actividades específicas por lead
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.lead_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
    agente_asignado TEXT NOT NULL CHECK (agente_asignado IN ('ivy','rose','salo','jeanette','human','system')),
    tipo_tarea TEXT NOT NULL CHECK (tipo_tarea IN (
        'call', 'whatsapp', 'email', 'viewing', 'booking_confirmado',
        'documento_enviado', 'documento_recibido', 'contrato_enviado',
        'follow_up', 'nurturing', 'recordatorio', 'otra'
    )),
    titulo TEXT NOT NULL,
    descripcion TEXT,
    fecha_programada DATE NOT NULL,
    hora_programada TIME,
    estado TEXT NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente','en_progreso','completado','cancelado','fallido')),
    prioridad TEXT DEFAULT 'normal' CHECK (prioridad IN ('baja','normal','alta','urgente')),
    resultado TEXT,
    notas_resultado TEXT,
    recordatorio_enviado BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizado_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completado_at TIMESTAMPTZ
);

COMMENT ON TABLE public.lead_tasks IS 'Tareas y actividades específicas por lead.Seguimiento detallado de acciones.';

CREATE INDEX IF NOT EXISTS idx_lead_tasks_lead ON public.lead_tasks (lead_id);
CREATE INDEX IF NOT EXISTS idx_lead_tasks_fecha_estado ON public.lead_tasks (fecha_programada, estado);
CREATE INDEX IF NOT EXISTS idx_lead_tasks_agente_estado ON public.lead_tasks (agente_asignado, estado);
CREATE INDEX IF NOT EXISTS idx_lead_tasks_pendientes ON public.lead_tasks (estado, fecha_programada) WHERE estado = 'pendiente';

-- Trigger updated_at
CREATE TRIGGER trg_lead_tasks_updated_at
    BEFORE UPDATE ON public.lead_tasks
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_updated_at();

-- ─── 3. TABLA: lead_nurturing_sequences ─────────────────────────────────────
-- Secuencias de nurturing automatizado
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.lead_nurturing_sequences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
    tipo_secuencia TEXT NOT NULL CHECK (tipo_secuencia IN ('welcome','follow_up_3dias','follow_up_7dias','post_viewing','post_booking','reactivacion','intl_welcome')),
    paso_actual INTEGER NOT NULL DEFAULT 1,
    total_pasos INTEGER NOT NULL DEFAULT 3,
    estado TEXT NOT NULL DEFAULT 'activa' CHECK (estado IN ('activa','pausada','completada','cancelada')),
    ultimo_paso_enviado_at TIMESTAMPTZ,
    proximo_paso_fecha DATE,
    parametros JSONB DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizado_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.lead_nurturing_sequences IS 'Sequencias de nurturing automatizado por lead.';

CREATE INDEX IF NOT EXISTS idx_nurturing_lead ON public.lead_nurturing_sequences (lead_id);
CREATE INDEX IF NOT EXISTS idx_nurturing_activas ON public.lead_nurturing_sequences (estado) WHERE estado = 'activa';
CREATE INDEX IF NOT EXISTS idx_nurturing_proximo_paso ON public.lead_nurturing_sequences (proximo_paso_fecha) WHERE estado = 'activa';

-- Trigger updated_at
CREATE TRIGGER trg_nurturing_updated_at
    BEFORE UPDATE ON public.lead_nurturing_sequences
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_updated_at();

-- ─── 4. FUNCIÓN: Registrar cambio de score ─────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_record_score_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Solo registrar si el score cambió
    IF OLD.scl_score IS DISTINCT FROM NEW.scl_score THEN
        INSERT INTO public.lead_score_history
            (lead_id, scl_score_anterior, scl_score_nuevo, cambio_score, detalle_cambio)
        VALUES
            (NEW.id, OLD.scl_score, NEW.scl_score, 
             COALESCE(NEW.scl_score, 0) - COALESCE(OLD.scl_score, 0),
             jsonb_build_object(
                 'urgency_score', NEW.urgency_score,
                 'data_completeness', NEW.data_completeness,
                 'budget_fit', NEW.budget_fit,
                 'wab_engagement_count', NEW.wab_engagement_count
             ));
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_leads_score_history ON public.leads;
CREATE TRIGGER trg_leads_score_history
    AFTER UPDATE OF scl_score ON public.leads
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_record_score_change();

-- ─── 5. VISTA: Tasks pendientes para hoy ───────────────────────────────────

CREATE OR REPLACE VIEW public.v_tasks_hoy AS
SELECT
    t.id AS task_id,
    l.id AS lead_id,
    l.nombre,
    l.telefono,
    l.canal_origen,
    l.zona_preferida,
    l.presupuesto_max,
    l.scl_score,
    l.status AS lead_status,
    t.agente_asignado,
    t.tipo_tarea,
    t.titulo,
    t.descripcion,
    t.fecha_programada,
    t.hora_programada,
    t.estado,
    t.prioridad,
    t.created_at
FROM public.lead_tasks t
JOIN public.leads l ON t.lead_id = l.id
WHERE t.fecha_programada = CURRENT_DATE
AND t.estado = 'pendiente'
ORDER BY 
    CASE t.prioridad 
        WHEN 'urgente' THEN 1 
        WHEN 'alta' THEN 2 
        WHEN 'normal' THEN 3 
        ELSE 4 
    END,
    t.hora_programada ASC;

-- ─── 6. VISTA: Tasks próximas (próximos 7 días) ───────────────────────────

CREATE OR REPLACE VIEW public.v_tasks_proximas AS
SELECT
    t.id AS task_id,
    l.id AS lead_id,
    l.nombre,
    l.telefono,
    l.canal_origen,
    l.zona_preferida,
    l.scl_score,
    t.agente_asignado,
    t.tipo_tarea,
    t.titulo,
    t.fecha_programada,
    t.estado,
    t.prioridad,
    t.fecha_programada - CURRENT_DATE AS dias_restantes
FROM public.lead_tasks t
JOIN public.leads l ON t.lead_id = l.id
WHERE t.estado = 'pendiente'
AND t.fecha_programada BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
ORDER BY t.fecha_programada ASC, t.prioridad DESC;

-- ─── 7. VISTA: Dashboard de nurture ───────────────────────────────────────

CREATE OR REPLACE VIEW public.v_nurturing_dashboard AS
SELECT
    l.asignado_a AS agente,
    COUNT(*) FILTER (WHERE ns.estado = 'activa') AS secuencias_activas,
    COUNT(*) FILTER (WHERE ns.estado = 'completada') AS secuencias_completadas,
    COUNT(*) FILTER (WHERE ns.estado = 'activa' AND ns.proximo_paso_fecha = CURRENT_DATE) AS pasos_hoy,
    COUNT(*) FILTER (WHERE ns.estado = 'activa' AND ns.proximo_paso_fecha < CURRENT_DATE) AS pasos_atrasados
FROM public.lead_nurturing_sequences ns
JOIN public.leads l ON ns.lead_id = l.id
WHERE l.asignado_a IN ('ivy','rose','salo','jeanette')
GROUP BY l.asignado_a;

-- ─── 8. VISTA: Score history por lead ─────────────────────────────────────

CREATE OR REPLACE VIEW public.v_lead_score_evolution AS
SELECT
    l.id AS lead_id,
    l.nombre,
    l.scl_score AS score_actual,
    (
        SELECT jsonb_agg(
            jsonb_build_object(
                'fecha', created_at::DATE,
                'score', scl_score_nuevo,
                'cambio', cambio_score,
                'factor', factor_cambio
            ) ORDER BY created_at DESC
        )
        FROM public.lead_score_history
        WHERE lead_id = l.id
    ) AS historial_score,
    (
        SELECT COUNT(*)::INTEGER
        FROM public.lead_score_history
        WHERE lead_id = l.id
    ) AS total_cambios,
    (
        SELECT MAX(created_at)
        FROM public.lead_score_history
        WHERE lead_id = l.id
    ) AS ultimo_cambio
FROM public.leads l
WHERE l.scl_score IS NOT NULL
ORDER BY l.scl_score DESC;

-- ─── 9. Actualizar v_daily_summary ─────────────────────────────────────────

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
    (SELECT COUNT(*) FROM public.lead_tasks WHERE fecha_programada = CURRENT_DATE AND estado = 'pendiente') AS tasks_hoy,
    (SELECT COUNT(*) FROM public.lead_nurturing_sequences WHERE estado = 'activa' AND proximo_paso_fecha = CURRENT_DATE) AS nurturing_pasos_hoy,
    NOW() AT TIME ZONE 'Europe/London' AS generado_at_london;

-- ─── 10. RLS para lead_score_history ───────────────────────────────────────

ALTER TABLE public.lead_score_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role_score_history" ON public.lead_score_history
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "alex_read_score_history" ON public.lead_score_history
    FOR SELECT USING (auth.jwt() ->> 'agent_id' = 'alex');

CREATE POLICY "agents_read_own_score_history" ON public.lead_score_history
    FOR SELECT USING (
        auth.jwt() ->> 'agent_id' IN ('ivy','rose','salo','jeanette')
    );

-- ─── 11. RLS para lead_tasks ───────────────────────────────────────────────

ALTER TABLE public.lead_tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role_tasks" ON public.lead_tasks
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "ivy_tasks" ON public.lead_tasks
    FOR ALL USING (auth.jwt() ->> 'agent_id' = 'ivy' AND agente_asignado = 'ivy');

CREATE POLICY "rose_tasks" ON public.lead_tasks
    FOR ALL USING (auth.jwt() ->> 'agent_id' = 'rose' AND agente_asignado = 'rose');

CREATE POLICY "salo_tasks" ON public.lead_tasks
    FOR ALL USING (auth.jwt() ->> 'agent_id' = 'salo' AND agente_asignado = 'salo');

CREATE POLICY "jeanette_tasks" ON public.lead_tasks
    FOR ALL USING (auth.jwt() ->> 'agent_id' = 'jeanette');

CREATE POLICY "alex_read_tasks" ON public.lead_tasks
    FOR SELECT USING (auth.jwt() ->> 'agent_id' = 'alex');

-- ─── 12. RLS para lead_nurturing_sequences ────────────────────────────────

ALTER TABLE public.lead_nurturing_sequences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role_nurturing" ON public.lead_nurturing_sequences
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "ivy_nurturing" ON public.lead_nurturing_sequences
    FOR ALL USING (
        auth.jwt() ->> 'agent_id' = 'ivy' 
        AND lead_id IN (SELECT id FROM public.leads WHERE asignado_a = 'ivy')
    );

CREATE POLICY "rose_nurturing" ON public.lead_nurturing_sequences
    FOR ALL USING (
        auth.jwt() ->> 'agent_id' = 'rose'
        AND lead_id IN (SELECT id FROM public.leads WHERE asignado_a = 'rose')
    );

CREATE POLICY "salo_nurturing" ON public.lead_nurturing_sequences
    FOR ALL USING (
        auth.jwt() ->> 'agent_id' = 'salo'
        AND lead_id IN (SELECT id FROM public.leads WHERE asignado_a = 'salo')
    );

CREATE POLICY "jeanette_nurturing" ON public.lead_nurturing_sequences
    FOR ALL USING (
        auth.jwt() ->> 'agent_id' = 'jeanette'
        AND lead_id IN (SELECT id FROM public.leads WHERE asignado_a = 'jeanette')
    );

CREATE POLICY "alex_read_nurturing" ON public.lead_nurturing_sequences
    FOR SELECT USING (auth.jwt() ->> 'agent_id' = 'alex');

-- ─── 13. Función: Crear task ───────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_create_task(
    p_lead_id UUID,
    p_agente TEXT,
    p_tipo_tarea TEXT,
    p_titulo TEXT,
    p_fecha_programada DATE,
    p_descripcion TEXT DEFAULT NULL,
    p_hora_programada TIME DEFAULT NULL,
    p_prioridad TEXT DEFAULT 'normal'
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_task_id UUID;
BEGIN
    INSERT INTO public.lead_tasks
        (lead_id, agente_asignado, tipo_tarea, titulo, descripcion, fecha_programada, hora_programada, prioridad)
    VALUES
        (p_lead_id, p_agente, p_tipo_tarea, p_titulo, p_descripcion, p_fecha_programada, p_hora_programada, p_prioridad)
    RETURNING id INTO v_task_id;

    RETURN v_task_id;
END;
$$;

-- ─── 14. Función: Completar task ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_complete_task(
    p_task_id UUID,
    p_resultado TEXT DEFAULT NULL,
    p_notas TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.lead_tasks
    SET
        estado = 'completado',
        resultado = p_resultado,
        notas_resultado = p_notas,
        completado_at = NOW()
    WHERE id = p_task_id;
END;
$$;

-- ─── 15. Función: Iniciar secuencia de nurturing ──────────────────────────

CREATE OR REPLACE FUNCTION public.fn_start_nurturing_sequence(
    p_lead_id UUID,
    p_tipo_secuencia TEXT,
    p_parametros JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_seq_id UUID;
    v_dias_interval INTEGER;
BEGIN
    CASE p_tipo_secuencia
        WHEN 'welcome' THEN v_dias_interval := 1;
        WHEN 'follow_up_3dias' THEN v_dias_interval := 3;
        WHEN 'follow_up_7dias' THEN v_dias_interval := 7;
        WHEN 'post_viewing' THEN v_dias_interval := 2;
        WHEN 'post_booking' THEN v_dias_interval := 1;
        WHEN 'reactivacion' THEN v_dias_interval := 3;
        WHEN 'intl_welcome' THEN v_dias_interval := 1;
        ELSE v_dias_interval := 1;
    END CASE;

    INSERT INTO public.lead_nurturing_sequences
        (lead_id, tipo_secuencia, total_pasos, estado, proximo_paso_fecha, parametros)
    VALUES
        (p_lead_id, p_tipo_secuencia, 3, 'activa', CURRENT_DATE + v_dias_interval, p_parametros)
    RETURNING id INTO v_seq_id;

    RETURN v_seq_id;
END;
$$;

-- ─── 16. Función: Siguiente paso de nurturing ──────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_next_nurturing_step(p_seq_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_seq RECORD;
    v_dias_interval INTEGER;
BEGIN
    SELECT * INTO v_seq FROM public.lead_nurturing_sequences WHERE id = p_seq_id;

    IF v_seq.paso_actual >= v_seq.total_pasos THEN
        UPDATE public.lead_nurturing_sequences
        SET estado = 'completada', actualizado_at = NOW()
        WHERE id = p_seq_id;
    ELSE
        CASE v_seq.tipo_secuencia
            WHEN 'welcome' THEN v_dias_interval := 1;
            WHEN 'follow_up_3dias' THEN v_dias_interval := 3;
            WHEN 'follow_up_7dias' THEN v_dias_interval := 7;
            ELSE v_dias_interval := 1;
        END CASE;

        UPDATE public.lead_nurturing_sequences
        SET 
            paso_actual = paso_actual + 1,
            ultimo_paso_enviado_at = NOW(),
            proximo_paso_fecha = CURRENT_DATE + v_dias_interval,
            actualizado_at = NOW()
        WHERE id = p_seq_id;
    END IF;
END;
$$;

-- =============================================================================
-- FIN DE MIGRACIÓN
-- =============================================================================