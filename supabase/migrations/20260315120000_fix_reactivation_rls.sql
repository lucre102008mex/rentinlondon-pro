-- =============================================================================
-- Migración 20260315120000: Corregir políticas RLS de reactivación
-- RentInLondon PRO
-- Actualiza las políticas RLS de la tabla reactivation para usar el nuevo
-- sistema de autorización basado en agents_registry
-- =============================================================================

-- ─── 1. ELIMINAR POLÍTICAS ANTIGUAS ────────────────────────────────────────

DROP POLICY IF EXISTS reactivation_insert_script_runner ON public.reactivation;
DROP POLICY IF EXISTS reactivation_select_alex_sr ON public.reactivation;
DROP POLICY IF EXISTS reactivation_update_alex ON public.reactivation;
DROP POLICY IF EXISTS reactivation_update_wa_agents ON public.reactivation;

-- ─── 2. CREAR NUEVAS POLÍTICAS BASADAS EN AGENTS_REGISTRY ────────────────

-- POLÍTICA DE LECTURA: Agentes autorizados pueden leer
CREATE POLICY reactivation_select_authorized ON public.reactivation
    FOR SELECT USING (
        public.fn_is_authorized_reader() OR auth.role() = 'service_role'
    );

-- POLÍTICA DE INSERCIÓN: Solo script_runner puede insertar (preparar mensajes)
CREATE POLICY reactivation_insert_script ON public.reactivation
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.agents_registry
            WHERE email = auth.jwt() ->> 'email'
            AND agent_id = 'script'
        ) OR auth.role() = 'service_role'
    );

-- POLÍTICA DE ACTUALIZACIÓN: 
-- - Alex puede actualizar cualquier registro (aprobar/rechazar)
-- - Agentes de WhatsApp pueden actualizar SOLO sus registros asignados a 'enviado'
CREATE POLICY reactivation_update_agents ON public.reactivation
    FOR UPDATE
    USING (
        -- Alex puede actualizar cualquier registro
        EXISTS (
            SELECT 1 FROM public.agents_registry
            WHERE email = auth.jwt() ->> 'email'
            AND agent_id = 'alex'
        )
        OR
        -- WhatsApp agentes pueden actualizar sus registros asignados a 'enviado'
        (
            EXISTS (
                SELECT 1 FROM public.agents_registry
                WHERE email = auth.jwt() ->> 'email'
                AND agent_id IN ('ivy', 'rose', 'salo', 'jeanette')
            )
            AND agente_asignado = (SELECT agent_id FROM public.agents_registry WHERE email = auth.jwt() ->> 'email')
            AND estado = 'aprobado'
        )
        OR auth.role() = 'service_role'
    )
    WITH CHECK (
        -- Alex puede cambiar a cualquier estado válido
        (
            EXISTS (
                SELECT 1 FROM public.agents_registry
                WHERE email = auth.jwt() ->> 'email'
                AND agent_id = 'alex'
            )
            AND estado IN ('pendiente', 'aprobado', 'rechazado', 'enviado')
        )
        OR
        -- WhatsApp agentes solo pueden cambiar de 'aprobado' a 'enviado' en sus registros
        (
            EXISTS (
                SELECT 1 FROM public.agents_registry
                WHERE email = auth.jwt() ->> 'email'
                AND agent_id IN ('ivy', 'rose', 'salo', 'jeanette')
            )
            AND agente_asignado = (SELECT agent_id FROM public.agents_registry WHERE email = auth.jwt() ->> 'email')
            AND estado = 'enviado'
        )
        OR auth.role() = 'service_role'
    );

-- ─── 3. COMENTARIO ────────────────────────────────────────────────────────

COMMENT ON POLICY reactivation_select_authorized ON public.reactivation IS 'Permite lectura a agentes autorizados mediante agents_registry';
COMMENT ON POLICY reactivation_insert_script ON public.reactivation IS 'Permite inserción solo al agente script (script-runner)';
COMMENT ON POLICY reactivation_update_agents ON public.reactivation IS 'Permite actualización: Alex (cualquier cambio), WhatsApp agents (solo asignados a enviado)';
