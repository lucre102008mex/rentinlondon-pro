-- =============================================================================
-- Migración 20260315000000: Añadir permisos de escritura a agentes
-- RentInLondon PRO
-- Agrega columna can_write y funciones de autorización separadas
-- =============================================================================

-- ─── 1. AÑADIR COLUMNA can_write ─────────────────────────────────────────

ALTER TABLE public.agents_registry 
ADD COLUMN IF NOT EXISTS can_write BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN public.agents_registry.can_write IS 'Indica si el agente tiene permisos de escritura (INSERT/UPDATE/DELETE)';

-- ─── 2. ASIGNAR PERMISOS DE ESCRITURA A AGENTES ESPECÍFICOS ──────────────

UPDATE public.agents_registry 
SET can_write = TRUE 
WHERE agent_id IN ('alex', 'ivy', 'salo', 'rose', 'jeanette');

-- ─── 3. CREAR FUNCIÓN DE AUTORIZACIÓN DE LECTURA ────────────────────────

CREATE OR REPLACE FUNCTION public.fn_is_authorized_reader()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.agents_registry
        WHERE email = auth.jwt() ->> 'email'
    );
END;
$$;

COMMENT ON FUNCTION public.fn_is_authorized_reader() IS 'Verifica si el usuario autenticado es un agente autorizado para lectura';

-- ─── 4. CREAR FUNCIÓN DE AUTORIZACIÓN DE ESCRITURA ──────────────────────

CREATE OR REPLACE FUNCTION public.fn_is_authorized_writer()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.agents_registry
        WHERE email = auth.jwt() ->> 'email'
        AND can_write = TRUE
    );
END;
$$;

COMMENT ON FUNCTION public.fn_is_authorized_writer() IS 'Verifica si el usuario autenticado es un agente autorizado para escritura';

-- ─── 5. ACTUALIZAR POLÍTICAS RLS PARA SEPARAR LECTURA/ESCRITURA ────────

-- LEADS
DROP POLICY IF EXISTS "agents_leads_read" ON public.leads;
DROP POLICY IF EXISTS "agents_leads_write" ON public.leads;

CREATE POLICY "agents_leads_read" ON public.leads
    FOR SELECT USING (
        public.fn_is_authorized_reader() OR auth.role() = 'service_role'
    );

CREATE POLICY "agents_leads_write" ON public.leads
    FOR ALL USING (
        public.fn_is_authorized_writer() OR auth.role() = 'service_role'
    )
    WITH CHECK (
        public.fn_is_authorized_writer() OR auth.role() = 'service_role'
    );

-- BOOKINGS
DROP POLICY IF EXISTS "agents_bookings_v2" ON public.bookings;
DROP POLICY IF EXISTS "agents_bookings_read" ON public.bookings;
DROP POLICY IF EXISTS "agents_bookings_write" ON public.bookings;

CREATE POLICY "agents_bookings_read" ON public.bookings
    FOR SELECT USING (
        public.fn_is_authorized_reader() OR auth.role() = 'service_role'
    );

CREATE POLICY "agents_bookings_write" ON public.bookings
    FOR ALL USING (
        public.fn_is_authorized_writer() OR auth.role() = 'service_role'
    )
    WITH CHECK (
        public.fn_is_authorized_writer() OR auth.role() = 'service_role'
    );

-- FOLLOWUPS
DROP POLICY IF EXISTS "agents_followups_v2" ON public.lead_followups;
DROP POLICY IF EXISTS "agents_followups_read" ON public.lead_followups;
DROP POLICY IF EXISTS "agents_followups_write" ON public.lead_followups;

CREATE POLICY "agents_followups_read" ON public.lead_followups
    FOR SELECT USING (
        public.fn_is_authorized_reader() OR auth.role() = 'service_role'
    );

CREATE POLICY "agents_followups_write" ON public.lead_followups
    FOR ALL USING (
        public.fn_is_authorized_writer() OR auth.role() = 'service_role'
    )
    WITH CHECK (
        public.fn_is_authorized_writer() OR auth.role() = 'service_role'
    );

-- TASKS
DROP POLICY IF EXISTS "agents_tasks_v2" ON public.lead_tasks;
DROP POLICY IF EXISTS "agents_tasks_read" ON public.lead_tasks;
DROP POLICY IF EXISTS "agents_tasks_write" ON public.lead_tasks;

CREATE POLICY "agents_tasks_read" ON public.lead_tasks
    FOR SELECT USING (
        public.fn_is_authorized_reader() OR auth.role() = 'service_role'
    );

CREATE POLICY "agents_tasks_write" ON public.lead_tasks
    FOR ALL USING (
        public.fn_is_authorized_writer() OR auth.role() = 'service_role'
    )
    WITH CHECK (
        public.fn_is_authorized_writer() OR auth.role() = 'service_role'
    );

-- NURTURING
DROP POLICY IF EXISTS "agents_nurturing_v2" ON public.lead_nurturing_sequences;
DROP POLICY IF EXISTS "agents_nurturing_read" ON public.lead_nurturing_sequences;
DROP POLICY IF EXISTS "agents_nurturing_write" ON public.lead_nurturing_sequences;

CREATE POLICY "agents_nurturing_read" ON public.lead_nurturing_sequences
    FOR SELECT USING (
        public.fn_is_authorized_reader() OR auth.role() = 'service_role'
    );

CREATE POLICY "agents_nurturing_write" ON public.lead_nurturing_sequences
    FOR ALL USING (
        public.fn_is_authorized_writer() OR auth.role() = 'service_role'
    )
    WITH CHECK (
        public.fn_is_authorized_writer() OR auth.role() = 'service_role'
    );

-- SCORE HISTORY
DROP POLICY IF EXISTS "agents_score_history_v2" ON public.lead_score_history;
DROP POLICY IF EXISTS "agents_score_history_read" ON public.lead_score_history;
DROP POLICY IF EXISTS "agents_score_history_write" ON public.lead_score_history;

CREATE POLICY "agents_score_history_read" ON public.lead_score_history
    FOR SELECT USING (
        public.fn_is_authorized_reader() OR auth.role() = 'service_role'
    );

CREATE POLICY "agents_score_history_write" ON public.lead_score_history
    FOR SELECT USING (-- SCORE HISTORY is typically read-only for agents
        public.fn_is_authorized_reader() OR auth.role() = 'service_role'
    );

-- Note: SCORE HISTORY write operations are typically handled by system/triggers only