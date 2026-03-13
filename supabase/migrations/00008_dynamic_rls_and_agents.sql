-- =============================================================================
-- Migración 00008: RLS Dinámico y Registro de Agentes
-- RentInLondon PRO
-- Reemplaza reglas hard-coded por una tabla de referencia de agentes.
-- =============================================================================

-- ─── 1. TABLA: agents_registry ──────────────────────────────────────────────
-- Registro central de correos autorizados y sus roles
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.agents_registry (
    email TEXT PRIMARY KEY,
    agent_id TEXT UNIQUE NOT NULL,
    role TEXT NOT NULL DEFAULT 'agent' CHECK (role IN ('admin', 'agent', 'support')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.agents_registry IS 'Registro de correos electrónicos autorizados para acceder vía RLS.';

-- ─── 2. SEED: Agentes iniciales ──────────────────────────────────────────────

INSERT INTO public.agents_registry (email, agent_id, role)
VALUES 
    ('alex@rentinlondon.com', 'alex', 'admin'),
    ('owner@rentinlondon.com', 'alex', 'admin'),
    ('ivy@rentinlondon.com', 'ivy', 'agent'),
    ('rose@rentinlondon.com', 'rose', 'agent'),
    ('salo@rentinlondon.com', 'salo', 'agent'),
    ('jeanette@rentinlondon.com', 'jeanette', 'agent')
ON CONFLICT (email) DO UPDATE 
SET agent_id = EXCLUDED.agent_id, role = EXCLUDED.role;

-- ─── 3. FUNCION HELPER: Es Agente? ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_is_authorized_agent()
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

-- ─── 4. ACTUALIZACIÓN DE POLÍTICAS RLS ───────────────────────────────────────
-- Reemplazamos las menciones hard-coded por consultas a agents_registry

-- LEADS
DROP POLICY IF EXISTS "alex_leads_read" ON public.leads;
CREATE POLICY "agents_leads_read" ON public.leads
    FOR SELECT USING (
        public.fn_is_authorized_agent() OR auth.role() = 'service_role'
    );

-- BOOKINGS
DROP POLICY IF EXISTS "agents_bookings" ON public.bookings;
CREATE POLICY "agents_bookings_v2" ON public.bookings
    FOR ALL USING (
        public.fn_is_authorized_agent() OR auth.role() = 'service_role'
    );

-- FOLLOWUPS
DROP POLICY IF EXISTS "agents_followups" ON public.lead_followups;
CREATE POLICY "agents_followups_v2" ON public.lead_followups
    FOR ALL USING (
        public.fn_is_authorized_agent() OR auth.role() = 'service_role'
    );

-- TASKS
DROP POLICY IF EXISTS "agents_tasks" ON public.lead_tasks;
CREATE POLICY "agents_tasks_v2" ON public.lead_tasks
    FOR ALL USING (
        public.fn_is_authorized_agent() OR auth.role() = 'service_role'
    );

-- NURTURING
DROP POLICY IF EXISTS "agents_nurturing" ON public.lead_nurturing_sequences;
CREATE POLICY "agents_nurturing_v2" ON public.lead_nurturing_sequences
    FOR ALL USING (
        public.fn_is_authorized_agent() OR auth.role() = 'service_role'
    );

-- SCORE HISTORY
DROP POLICY IF EXISTS "analysis_score_history" ON public.lead_score_history;
CREATE POLICY "agents_score_history_v2" ON public.lead_score_history
    FOR SELECT USING (
        public.fn_is_authorized_agent() OR auth.role() = 'service_role'
    );
