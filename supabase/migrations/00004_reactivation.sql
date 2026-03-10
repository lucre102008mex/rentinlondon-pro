-- =============================================================================
-- Migración 00004: Tabla reactivation + Deduplicación de leads
-- RentInLondon PRO
-- =============================================================================

-- ─── 1. Tabla de reactivación de leads dormantes ────────────────────────────
-- Reemplaza el almacenamiento en agent_logs.metadata.requires_approval
-- con una tabla dedicada para el flujo de reactivación con aprobación humana.

CREATE TABLE IF NOT EXISTS public.reactivation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  mensaje_propuesto TEXT NOT NULL,
  template_usado TEXT,
  agente_asignado TEXT NOT NULL,
  estado TEXT NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN ('pendiente', 'aprobado', 'rechazado', 'enviado')),
  aprobado_por TEXT,
  aprobado_at TIMESTAMPTZ,
  enviado_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para consultas frecuentes
CREATE INDEX IF NOT EXISTS idx_reactivation_estado ON public.reactivation(estado);
CREATE INDEX IF NOT EXISTS idx_reactivation_lead_id ON public.reactivation(lead_id);
CREATE INDEX IF NOT EXISTS idx_reactivation_agente ON public.reactivation(agente_asignado);

-- Trigger para updated_at automático
CREATE OR REPLACE FUNCTION fn_reactivation_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reactivation_updated_at
  BEFORE UPDATE ON public.reactivation
  FOR EACH ROW
  EXECUTE FUNCTION fn_reactivation_updated_at();

-- RLS en reactivation
ALTER TABLE public.reactivation ENABLE ROW LEVEL SECURITY;

-- script-runner puede insertar (preparar mensajes)
CREATE POLICY reactivation_insert_script_runner ON public.reactivation
  FOR INSERT
  WITH CHECK (current_setting('request.jwt.claims', true)::json->>'role' = 'script_runner_role');

-- Alex y script-runner pueden leer
CREATE POLICY reactivation_select_alex_sr ON public.reactivation
  FOR SELECT
  USING (
    current_setting('request.jwt.claims', true)::json->>'role' IN ('alex_role', 'script_runner_role')
  );

-- Alex puede actualizar estado (aprobar/rechazar)
CREATE POLICY reactivation_update_alex ON public.reactivation
  FOR UPDATE
  USING (current_setting('request.jwt.claims', true)::json->>'role' = 'alex_role')
  WITH CHECK (current_setting('request.jwt.claims', true)::json->>'role' = 'alex_role');

-- Agentes de WhatsApp pueden actualizar a 'enviado' solo sus registros asignados
CREATE POLICY reactivation_update_wa_agents ON public.reactivation
  FOR UPDATE
  USING (
    current_setting('request.jwt.claims', true)::json->>'role' IN ('ivy_role', 'rose_role', 'salo_role', 'jeanette_role')
    AND agente_asignado = current_setting('request.jwt.claims', true)::json->>'agent_name'
    AND estado = 'aprobado'
  )
  WITH CHECK (estado = 'enviado');


-- ─── 2. Deduplicación de leads por teléfono ─────────────────────────────────
-- Cuando se inserta un lead con un teléfono que ya existe,
-- se actualiza el lead existente en vez de crear un duplicado.

CREATE OR REPLACE FUNCTION fn_deduplicate_lead()
RETURNS TRIGGER AS $$
DECLARE
  existing_id UUID;
BEGIN
  -- Buscar lead existente con el mismo teléfono (normalizado)
  SELECT id INTO existing_id
  FROM public.leads
  WHERE telefono = NEW.telefono
    AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
  LIMIT 1;

  IF existing_id IS NOT NULL THEN
    -- Actualizar el lead existente con datos nuevos (si los nuevos no son NULL)
    UPDATE public.leads
    SET
      ultima_interaccion = NOW(),
      lead_origin_details = COALESCE(NEW.lead_origin_details, lead_origin_details),
      updated_at = NOW()
    WHERE id = existing_id;

    -- Registrar la deduplicación en agent_logs
    INSERT INTO public.agent_logs (agente, accion, exito, metadata)
    VALUES (
      'system',
      'lead_deduplicated',
      true,
      jsonb_build_object(
        'existing_lead_id', existing_id,
        'duplicate_phone', NEW.telefono,
        'duplicate_canal', NEW.canal_origen,
        'duplicate_nombre', NEW.nombre
      )
    );

    -- Cancelar la inserción del duplicado
    RETURN NULL;
  END IF;

  -- Si no hay duplicado, permitir la inserción normal
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_deduplicate_lead
  BEFORE INSERT ON public.leads
  FOR EACH ROW
  EXECUTE FUNCTION fn_deduplicate_lead();

-- ─── 3. Vista de reactivaciones pendientes ──────────────────────────────────

CREATE OR REPLACE VIEW v_reactivation_pendientes AS
SELECT
  r.id AS reactivation_id,
  r.lead_id,
  l.nombre AS lead_nombre,
  l.telefono AS lead_telefono,
  l.zona_preferida,
  l.canal_origen,
  r.mensaje_propuesto,
  r.template_usado,
  r.agente_asignado,
  r.estado,
  r.created_at
FROM public.reactivation r
JOIN public.leads l ON r.lead_id = l.id
WHERE r.estado = 'pendiente'
ORDER BY r.created_at ASC;
