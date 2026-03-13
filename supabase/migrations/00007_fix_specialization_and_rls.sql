-- =============================================================================
-- Migración 00007: Corrección Integral - Lógica de Especialización y RLS
-- RentInLondon PRO
-- Corrige: 1) Asignación de agentes para follow-ups 2) Políticas RLS
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. CORRECCIÓN: Función de creación de follow-ups con lógica de especialización
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_create_followups_on_mudanza()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_agente_asignado TEXT;
BEGIN
    -- Si no hay fecha_mudanza, no crear follow-ups
    IF NEW.fecha_mudanza IS NULL THEN
        RETURN NEW;
    END IF;

    -- Si la fecha ya pasó, no crear follow-ups
    IF NEW.fecha_mudanza <= CURRENT_DATE THEN
        RETURN NEW;
    END IF;

    -- LÓGICA DE ESPECIALIZACIÓN: Determinar el agente correcto para follow-ups
    -- Los leads internacionales SIEMPRE van a Jeanette (su specialty)
    IF NEW.es_internacional = TRUE THEN
        v_agente_asignado := 'jeanette';
    -- Leads ya escalados a Jeanette permanecen con ella
    ELSIF NEW.escalado_jeanette = TRUE THEN
        v_agente_asignado := 'jeanette';
    -- Leads DSS con requisitos pendientes van a Jeanette (ella maneja casos complejos)
    ELSIF NEW.es_dss = TRUE AND NEW.dss_requisitos_cumplidos = FALSE THEN
        v_agente_asignado := 'jeanette';
    -- Para el resto, usar el agente asignado actual
    ELSE
        v_agente_asignado := COALESCE(NEW.asignado_a, 'ivy');
    END IF;

    -- Eliminar follow-ups pendientes anteriores (evitar duplicados)
    DELETE FROM public.lead_followups
    WHERE lead_id = NEW.id
    AND estado = 'pendiente';

    -- Crear 3 follow-ups: 15, 7, y 3 días antes
    INSERT INTO public.lead_followups
        (lead_id, agente_asignado, fecha_mudanza_original, dias_antes, fecha_seguimiento, tipo_seguimiento)
    VALUES
        (NEW.id, v_agente_asignado, NEW.fecha_mudanza, 15, NEW.fecha_mudanza - INTERVAL '15 days', 'recordatorio_mudanza'),
        (NEW.id, v_agente_asignado, NEW.fecha_mudanza, 7, NEW.fecha_mudanza - INTERVAL '7 days', 'recordatorio_mudanza'),
        (NEW.id, v_agente_asignado, NEW.fecha_mudanza, 3, NEW.fecha_mudanza - INTERVAL '3 days', 'recordatorio_mudanza')
    ON CONFLICT DO NOTHING;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_create_followups_on_mudanza() IS 
'Crea automáticamente 3 follow-ups (15, 7, 3 días antes) usando lógica de especialización:
- Leads internacionales → Jeanette
- Leads escalados a Jeanette → Jeanette  
- Leads DSS sin requisitos → Jeanette
- Resto → agente asignado';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. CORRECCIÓN: Trigger para reasignar follow-ups cuando lead se reasigna
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_reassign_followups_on_agent_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_nuevos_followups INTEGER;
BEGIN
    -- Solo ejecutar si cambió el agente asignado, es_internacional o escalado_jeanette
    IF OLD.asignado_a IS DISTINCT FROM NEW.asignado_a
       OR OLD.es_internacional IS DISTINCT FROM NEW.es_internacional
       OR OLD.escalado_jeanette IS DISTINCT FROM NEW.escalado_jeanette
       OR OLD.es_dss IS DISTINCT FROM NEW.es_dss
       OR OLD.dss_requisitos_cumplidos IS DISTINCT FROM NEW.dss_requisitos_cumplidos
    THEN
        -- Determinar el nuevo agente correcto usando la misma lógica
        IF NEW.es_internacional = TRUE THEN
            -- Reasignar follow-ups pendientes al agente correcto
            UPDATE public.lead_followups
            SET agente_asignado = 'jeanette',
                notas = COALESCE(notas, '') || ' | Reasignado automáticamente: lead es internacional'
            WHERE lead_id = NEW.id
            AND estado = 'pendiente'
            AND agente_asignado != 'jeanette';
            
        ELSIF NEW.escalado_jeanette = TRUE THEN
            UPDATE public.lead_followups
            SET agente_asignado = 'jeanette',
                notas = COALESCE(notas, '') || ' | Reasignado automáticamente: lead escalado a Jeanette'
            WHERE lead_id = NEW.id
            AND estado = 'pendiente'
            AND agente_asignado != 'jeanette';
            
        ELSIF NEW.es_dss = TRUE AND NEW.dss_requisitos_cumplidos = FALSE THEN
            UPDATE public.lead_followups
            SET agente_asignado = 'jeanette',
                notas = COALESCE(notas, '') || ' | Reasignado automáticamente: lead DSS sin requisitos'
            WHERE lead_id = NEW.id
            AND estado = 'pendiente'
            AND agente_asignado != 'jeanette';
        END IF;
        
        GET DIAGNOSTICS v_nuevos_followups = ROW_COUNT;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_leads_reassign_followups ON public.leads;
CREATE TRIGGER trg_leads_reassign_followups
    AFTER UPDATE OF asignado_a, es_internacional, escalado_jeanette, es_dss, dss_requisitos_cumplidos
    ON public.leads
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_reassign_followups_on_agent_change();

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. CORRECCIÓN: Función para obtener el agente correcto (utilidad)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_get_agent_for_followup(p_lead_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_lead RECORD;
    v_agente TEXT;
BEGIN
    -- Obtener datos del lead
    SELECT * INTO v_lead
    FROM public.leads
    WHERE id = p_lead_id;

    IF NOT FOUND THEN
        RETURN 'ivy'; -- Default
    END IF;

    -- Aplicar lógica de especialización
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

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. CORRECCIÓN: Política RLS basada en email en lugar de JWT claim
-- ═══════════════════════════════════════════════════════════════════════════════

-- Primero, eliminar políticas RLS problemáticas que usan auth.jwt()->>'agent_id'
DROP POLICY IF EXISTS "alex_read_leads" ON public.leads;
DROP POLICY IF EXISTS "ivy_leads_uk" ON public.leads;
DROP POLICY IF EXISTS "rose_leads_uk" ON public.leads;
DROP POLICY IF EXISTS "salo_leads_uk" ON public.leads;
DROP POLICY IF EXISTS "jeanette_leads" ON public.leads;
DROP POLICY IF EXISTS "alex_read_interactions" ON public.interactions;
DROP POLICY IF EXISTS "ivy_interactions" ON public.interactions;
DROP POLICY IF EXISTS "rose_interactions" ON public.interactions;
DROP POLICY IF EXISTS "salo_interactions" ON public.interactions;
DROP POLICY IF EXISTS "jeanette_interactions" ON public.interactions;
DROP POLICY IF EXISTS "ivy_logs" ON public.agent_logs;
DROP POLICY IF EXISTS "rose_logs" ON public.agent_logs;
DROP POLICY IF EXISTS "salo_logs" ON public.agent_logs;
DROP POLICY IF EXISTS "jeanette_logs" ON public.agent_logs;
DROP POLICY IF EXISTS "alex_read_compliance" ON public.compliance_audit;
DROP POLICY IF EXISTS "ivy_bookings" ON public.bookings;
DROP POLICY IF EXISTS "rose_bookings" ON public.bookings;
DROP POLICY IF EXISTS "salo_bookings" ON public.bookings;
DROP POLICY IF EXISTS "jeanette_bookings" ON public.bookings;
DROP POLICY IF EXISTS "alex_read_bookings" ON public.bookings;
DROP POLICY IF EXISTS "ivy_followups" ON public.lead_followups;
DROP POLICY IF EXISTS "rose_followups" ON public.lead_followups;
DROP POLICY IF EXISTS "salo_followups" ON public.lead_followups;
DROP POLICY IF EXISTS "jeanette_followups" ON public.lead_followups;
DROP POLICY IF EXISTS "alex_read_followups" ON public.lead_followups;
DROP POLICY IF EXISTS "ivy_tasks" ON public.lead_tasks;
DROP POLICY IF EXISTS "rose_tasks" ON public.lead_tasks;
DROP POLICY IF EXISTS "salo_tasks" ON public.lead_tasks;
DROP POLICY IF EXISTS "jeanette_tasks" ON public.lead_tasks;
DROP POLICY IF EXISTS "alex_read_tasks" ON public.lead_tasks;
DROP POLICY IF EXISTS "ivy_nurturing" ON public.lead_nurturing_sequences;
DROP POLICY IF EXISTS "rose_nurturing" ON public.lead_nurturing_sequences;
DROP POLICY IF EXISTS "salo_nurturing" ON public.lead_nurturing_sequences;
DROP POLICY IF EXISTS "jeanette_nurturing" ON public.lead_nurturing_sequences;
DROP POLICY IF EXISTS "alex_read_nurturing" ON public.lead_nurturing_sequences;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. NUEVAS POLÍTICAS RLS: Usar service_role + acceso por email del agente
-- ═══════════════════════════════════════════════════════════════════════════════

-- LEADS: service_role tiene acceso total
CREATE POLICY "service_leads_all" ON public.leads
    FOR ALL USING (auth.role() = 'service_role');

-- LEADS: Acceso basado en email (suponiendo que auth.jwt()->>'email' contiene el email del agente)
-- NOTA: Esto requiere que los JWTs de Supabase incluyan el email del usuario
CREATE POLICY "alex_leads_read" ON public.leads
    FOR SELECT USING (
        (auth.jwt() ->> 'email') IN ('alex@rentinlondon.com', 'owner@rentinlondon.com')
        OR auth.role() = 'authenticated'
    );

-- INTERACTIONS: service_role tiene acceso total
CREATE POLICY "service_interactions_all" ON public.interactions
    FOR ALL USING (auth.role() = 'service_role');

-- AGENT_LOGS: service_role tiene acceso total
CREATE POLICY "service_logs_all" ON public.agent_logs
    FOR ALL USING (auth.role() = 'service_role');

-- AGENT_LOGS: Alex y owner pueden leer todos
CREATE POLICY "alex_logs_read" ON public.agent_logs
    FOR SELECT USING (
        (auth.jwt() ->> 'email') IN ('alex@rentinlondon.com', 'owner@rentinlondon.com')
        OR auth.role() = 'authenticated'
    );

-- BOOKINGS: service_role tiene acceso total
CREATE POLICY "service_bookings_all" ON public.bookings
    FOR ALL USING (auth.role() = 'service_role');

-- BOOKINGS: Acceso para agentes específicos (basado en email)
CREATE POLICY "agents_bookings" ON public.bookings
    FOR ALL USING (
        (auth.jwt() ->> 'email') LIKE '%@rentinlondon.com'
        OR auth.role() = 'service_role'
    );

-- LEAD_FOLLOWUPS: service_role tiene acceso total
CREATE POLICY "service_followups_all" ON public.lead_followups
    FOR ALL USING (auth.role() = 'service_role');

-- LEAD_FOLLOWUPS: Acceso basado en email del agente
-- Los agentes pueden ver los follow-ups que les corresponden por specialty
CREATE POLICY "agents_followups" ON public.lead_followups
    FOR ALL USING (
        (auth.jwt() ->> 'email') LIKE '%@rentinlondon.com'
        OR auth.role() = 'service_role'
    );

-- LEAD_TASKS: service_role tiene acceso total
CREATE POLICY "service_tasks_all" ON public.lead_tasks
    FOR ALL USING (auth.role() = 'service_role');

-- LEAD_TASKS: Acceso basado en email del agente
CREATE POLICY "agents_tasks" ON public.lead_tasks
    FOR ALL USING (
        (auth.jwt() ->> 'email') LIKE '%@rentinlondon.com'
        OR auth.role() = 'service_role'
    );

-- LEAD_NURTURING_SEQUENCES: service_role tiene acceso total
CREATE POLICY "service_nurturing_all" ON public.lead_nurturing_sequences
    FOR ALL USING (auth.role() = 'service_role');

-- LEAD_NURTURING_SEQUENCES: Acceso basado en email del agente
CREATE POLICY "agents_nurturing" ON public.lead_nurturing_sequences
    FOR ALL USING (
        (auth.jwt() ->> 'email') LIKE '%@rentinlondon.com'
        OR auth.role() = 'service_role'
    );

-- LEAD_SCORE_HISTORY: service_role tiene acceso total
CREATE POLICY "service_score_history_all" ON public.lead_score_history
    FOR ALL USING (auth.role() = 'service_role');

-- LEAD_SCORE_HISTORY: Acceso para análisis
CREATE POLICY "analysis_score_history" ON public.lead_score_history
    FOR SELECT USING (
        (auth.jwt() ->> 'email') LIKE '%@rentinlondon.com'
        OR auth.role() = 'service_role'
    );

-- COMPLIANCE_AUDIT: service_role tiene acceso total
CREATE POLICY "service_compliance_all" ON public.compliance_audit
    FOR ALL USING (auth.role() = 'service_role');

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. Vista actualizada: v_followups_hoy con lógica de especialización
-- ═══════════════════════════════════════════════════════════════════════════════

DROP VIEW IF EXISTS public.v_followups_hoy CASCADE;

CREATE VIEW public.v_followups_hoy AS
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
    l.es_internacional,
    l.escalado_jeanette,
    l.es_dss,
    l.dss_requisitos_cumplidos,
    EXTRACT(DAY FROM (NOW() - l.ultima_interaccion))::INTEGER AS dias_sin_contacto,
    -- Determinar el agente correcto basado en lógica de especialización
    CASE
        WHEN l.es_internacional = TRUE THEN 'jeanette'
        WHEN l.escalado_jeanette = TRUE THEN 'jeanette'
        WHEN l.es_dss = TRUE AND l.dss_requisitos_cumplidos = FALSE THEN 'jeanette'
        ELSE l.asignado_a
    END AS agente_correcto
FROM public.lead_followups f
JOIN public.leads l ON f.lead_id = l.id
WHERE f.fecha_seguimiento = CURRENT_DATE
AND f.estado = 'pendiente'
ORDER BY
    CASE f.dias_antes
        WHEN 3 THEN 1  -- Urgentes primero
        WHEN 7 THEN 2
        ELSE 3
    END,
    l.scl_score DESC;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. Vista actualizada: v_leads_activos con agente correcto
-- ═══════════════════════════════════════════════════════════════════════════════

DROP VIEW IF EXISTS public.v_leads_activos CASCADE;

CREATE VIEW public.v_leads_activos AS
SELECT
    l.id, l.nombre, l.telefono, l.email, l.canal_origen,
    l.zona_preferida, l.zonas_alternativas, l.presupuesto_min, l.presupuesto_max,
    l.tipo_propiedad, l.fecha_mudanza, l.duracion_contrato_meses,
    l.status, l.pipeline_stage,
    l.asignado_a,
    l.es_internacional, l.requiere_right_to_rent,
    l.urgency_score, l.scl_score, l.data_completeness, l.budget_fit,
    l.es_dss, l.dss_requisitos_cumplidos,
    l.response_speed_minutes, l.wab_engagement_count,
    l.escalado_jeanette, l.escalado_at, l.motivo_escalado,
    l.ultima_interaccion, l.total_interacciones,
    -- Calcular el agente correcto para follow-ups
    CASE
        WHEN l.es_internacional = TRUE THEN 'jeanette'
        WHEN l.escalado_jeanette = TRUE THEN 'jeanette'
        WHEN l.es_dss = TRUE AND l.dss_requisitos_cumplidos = FALSE THEN 'jeanette'
        ELSE l.asignado_a
    END AS agente_para_followups,
    CASE
        WHEN l.scl_score >= 7 THEN 'HOT'
        WHEN l.scl_score >= 4 THEN 'WARM'
        ELSE 'COLD'
    END AS temperatura,
    l.ultima_interaccion AT TIME ZONE 'Europe/London' AS ultima_interaccion_london,
    l.created_at AT TIME ZONE 'Europe/London' AS created_at_london,
    EXTRACT(EPOCH FROM (NOW() - l.ultima_interaccion)) / 3600 AS horas_sin_contacto
FROM public.leads l
WHERE l.status NOT IN ('rechazado','perdido','contrato_firmado')
ORDER BY l.scl_score DESC, l.ultima_interaccion DESC;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 8. Función helper: Reasignar follow-ups de un lead específico
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_reassign_followups_for_lead(p_lead_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_lead RECORD;
    v_agente TEXT;
    v_count INTEGER;
BEGIN
    -- Obtener datos del lead
    SELECT * INTO v_lead
    FROM public.leads
    WHERE id = p_lead_id;

    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    -- Determinar el agente correcto
    IF v_lead.es_internacional = TRUE THEN
        v_agente := 'jeanette';
    ELSIF v_lead.escalado_jeanette = TRUE THEN
        v_agente := 'jeanette';
    ELSIF v_lead.es_dss = TRUE AND v_lead.dss_requisitos_cumplidos = FALSE THEN
        v_agente := 'jeanette';
    ELSE
        v_agente := COALESCE(v_lead.asignado_a, 'ivy');
    END IF;

    -- Reasignar follow-ups pendientes
    UPDATE public.lead_followups
    SET agente_asignado = v_agente,
        notas = COALESCE(notas, '') || ' | Reasignado manualmente vía fn_reassign_followups_for_lead'
    WHERE lead_id = p_lead_id
    AND estado = 'pendiente'
    AND agente_asignado != v_agente;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    
    RETURN v_count;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 9. Función para reasignar TODOS los follow-ups existentes (utilidad)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_reassign_all_followups()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INTEGER := 0;
    v_lead RECORD;
BEGIN
    FOR v_lead IN SELECT id, es_internacional, escalado_jeanette, es_dss, dss_requisitos_cumplidos, asignado_a FROM public.leads LOOP
        v_count := v_count + fn_reassign_followups_for_lead(v_lead.id);
    END LOOP;
    
    RETURN v_count;
END;
$$;

-- =============================================================================
-- FIN DE MIGRACIÓN
-- =============================================================================