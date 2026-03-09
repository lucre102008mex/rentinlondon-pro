-- =============================================================================
-- Migración 00003: SCL — Sistema de Calificación de Leads
-- RentInLondon PRO
-- Escala: 0–10 puntos | Canal principal: WhatsApp Business (WAB)
-- Cumplimiento: UK Equality Act 2010
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1a. Modificar tabla `leads`
-- -----------------------------------------------------------------------------

-- Ampliar rango de urgency_score a 0-10 para compatibilidad
ALTER TABLE public.leads DROP CONSTRAINT IF EXISTS leads_urgency_score_check;
ALTER TABLE public.leads ADD CONSTRAINT leads_urgency_score_check CHECK (urgency_score BETWEEN 0 AND 10);

-- Nuevo campo: score compuesto SCL (0-10 puntos)
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS scl_score SMALLINT DEFAULT 0 CHECK (scl_score BETWEEN 0 AND 10);
COMMENT ON COLUMN public.leads.scl_score IS 'SCL — Sistema de Calificación de Leads. Escala 0-10. Mínimo 7 para cita en oficina.';

-- Flag de beneficio de vivienda (housing benefit) — solo para matching de propiedades
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS es_beneficio_housing BOOLEAN NOT NULL DEFAULT FALSE;
COMMENT ON COLUMN public.leads.es_beneficio_housing IS 'TRUE si el lead recibe beneficio de vivienda. Flag de matching únicamente — NO afecta el scl_score.';

-- Verificación de requisitos del landlord para leads con beneficio
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS beneficio_requisitos_cumplidos BOOLEAN DEFAULT FALSE;
COMMENT ON COLUMN public.leads.beneficio_requisitos_cumplidos IS 'TRUE cuando el lead ha cumplido los requisitos del landlord (garantor, meses adelantados, carta oficial, etc.). Permite acceso al pool completo de propiedades.';

-- Notas sobre situación de beneficio del lead
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS beneficio_notas TEXT;
COMMENT ON COLUMN public.leads.beneficio_notas IS 'Notas del agente sobre la situación de beneficio de vivienda del lead y requisitos pendientes.';

-- Contador de mensajes respondidos en WhatsApp Business
ALTER TABLE public.leads ADD COLUMN IF NOT EXISTS wab_engagement_count INTEGER DEFAULT 0 CHECK (wab_engagement_count >= 0);
COMMENT ON COLUMN public.leads.wab_engagement_count IS 'Número de mensajes respondidos por el lead en WhatsApp Business. Factor F5 del SCL.';

-- -----------------------------------------------------------------------------
-- 1b. Modificar tabla `properties`
-- -----------------------------------------------------------------------------

-- Indica si el landlord acepta leads con beneficio de vivienda
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS acepta_beneficio_housing BOOLEAN NOT NULL DEFAULT FALSE;
COMMENT ON COLUMN public.properties.acepta_beneficio_housing IS 'TRUE si el landlord acepta leads con beneficio de vivienda. Usado para matching con es_beneficio_housing.';

-- Requisitos específicos del landlord para leads con beneficio
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS beneficio_requisitos TEXT;
COMMENT ON COLUMN public.properties.beneficio_requisitos IS 'Descripción de los requisitos del landlord para leads con beneficio (ej: garantor requerido, 3 meses adelantados, carta oficial).';

-- -----------------------------------------------------------------------------
-- 1c. Función y trigger SCL
-- -----------------------------------------------------------------------------

-- =============================================================================
-- FUNCIÓN: fn_calculate_scl_score
-- SCL — Sistema de Calificación de Leads
-- Escala: 0–10 puntos
-- Canal principal: WhatsApp Business (WAB)
-- Cumplimiento: UK Equality Act 2010
-- =============================================================================
CREATE OR REPLACE FUNCTION public.fn_calculate_scl_score()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  score     SMALLINT := 0;
  days_move INTEGER;
BEGIN
  -- F1: Urgencia — Fecha de mudanza (0-3 pts)
  IF NEW.fecha_mudanza IS NOT NULL THEN
    days_move := (NEW.fecha_mudanza - CURRENT_DATE);
    IF days_move <= 7 THEN
      score := score + 3;
    ELSIF days_move <= 14 THEN
      score := score + 2;
    ELSIF days_move <= 30 THEN
      score := score + 1;
    END IF;
  END IF;

  -- F2: Velocidad de respuesta en WAB (0-2 pts)
  IF NEW.response_speed_minutes IS NOT NULL THEN
    IF NEW.response_speed_minutes <= 10 THEN
      score := score + 2;
    ELSIF NEW.response_speed_minutes <= 60 THEN
      score := score + 1;
    END IF;
  END IF;

  -- F3: Ajuste de presupuesto al mercado (0-2 pts)
  CASE NEW.budget_fit
    WHEN 'good'  THEN score := score + 2;
    WHEN 'maybe' THEN score := score + 1;
    ELSE NULL;
  END CASE;

  -- F4: Completitud de datos (0-2 pts)
  IF NEW.data_completeness >= 0.85 THEN
    score := score + 2;
  ELSIF NEW.data_completeness >= 0.57 THEN
    score := score + 1;
  END IF;

  -- F5: Engagement en WhatsApp Business (0-1 pt)
  IF NEW.wab_engagement_count >= 3 THEN
    score := score + 1;
  END IF;

  -- NOTA: es_beneficio_housing NO afecta el score — es solo flag de matching
  NEW.scl_score := LEAST(GREATEST(score, 0), 10);
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_leads_scl_score
  BEFORE INSERT OR UPDATE OF fecha_mudanza, response_speed_minutes, budget_fit, data_completeness, wab_engagement_count
  ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.fn_calculate_scl_score();

-- -----------------------------------------------------------------------------
-- 1d. Actualizar vista v_leads_activos
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW public.v_leads_activos AS
SELECT
  l.id, l.nombre, l.telefono, l.email, l.canal_origen,
  l.zona_preferida, l.zonas_alternativas, l.presupuesto_min, l.presupuesto_max,
  l.tipo_propiedad, l.fecha_mudanza, l.duracion_contrato_meses,
  l.status, l.pipeline_stage, l.asignado_a,
  l.es_internacional, l.requiere_right_to_rent,
  l.urgency_score, l.scl_score, l.data_completeness, l.budget_fit,
  l.es_beneficio_housing, l.beneficio_requisitos_cumplidos,
  l.response_speed_minutes, l.wab_engagement_count,
  l.escalado_jeanette, l.escalado_at, l.motivo_escalado,
  l.ultima_interaccion, l.total_interacciones,
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

-- -----------------------------------------------------------------------------
-- 1e. Vista v_leads_beneficio_pendientes
-- -----------------------------------------------------------------------------

-- Leads con beneficio de vivienda pendientes de verificación de requisitos
CREATE OR REPLACE VIEW public.v_leads_beneficio_pendientes AS
SELECT
  l.id, l.nombre, l.telefono,
  l.zona_preferida, l.tipo_propiedad, l.presupuesto_max,
  l.scl_score, l.beneficio_notas, l.asignado_a,
  l.ultima_interaccion AT TIME ZONE 'Europe/London' AS ultima_interaccion_london
FROM public.leads l
WHERE l.es_beneficio_housing = TRUE
  AND l.beneficio_requisitos_cumplidos = FALSE
  AND l.status NOT IN ('rechazado','perdido','contrato_firmado')
ORDER BY l.scl_score DESC, l.ultima_interaccion ASC;

-- -----------------------------------------------------------------------------
-- 1f. Vista v_match_beneficio
-- -----------------------------------------------------------------------------

-- Matching entre leads con beneficio y propiedades que los aceptan
CREATE OR REPLACE VIEW public.v_match_beneficio AS
SELECT
  l.id AS lead_id, l.nombre, l.zona_preferida, l.tipo_propiedad,
  l.presupuesto_max, l.scl_score, l.beneficio_requisitos_cumplidos, l.beneficio_notas,
  p.id AS property_id, p.direccion, p.zona, p.tipo,
  p.precio_mensual, p.acepta_beneficio_housing, p.beneficio_requisitos
FROM public.leads l
JOIN public.properties p ON (
  lower(l.zona_preferida) = lower(p.zona)
  AND l.tipo_propiedad = p.tipo
  AND l.presupuesto_max >= (p.precio_mensual * 0.85)::INTEGER
  AND p.acepta_beneficio_housing = TRUE
  AND p.estado = 'available'
)
WHERE l.es_beneficio_housing = TRUE
  AND l.status NOT IN ('rechazado','perdido','contrato_firmado')
ORDER BY l.scl_score DESC, p.precio_mensual ASC;

-- -----------------------------------------------------------------------------
-- 1g. Actualizar v_daily_summary
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW public.v_daily_summary AS
SELECT
  (CURRENT_DATE AT TIME ZONE 'Europe/London')::DATE AS fecha_london,
  (SELECT COUNT(*) FROM public.leads WHERE created_at::DATE = CURRENT_DATE) AS leads_nuevos_hoy,
  (SELECT COUNT(*) FROM public.leads WHERE status NOT IN ('rechazado','perdido','contrato_firmado')) AS leads_activos_total,
  (SELECT COUNT(*) FROM public.leads WHERE scl_score >= 7 AND status NOT IN ('rechazado','perdido','contrato_firmado')) AS leads_hot,
  (SELECT COUNT(*) FROM public.leads WHERE scl_score BETWEEN 4 AND 6 AND status NOT IN ('rechazado','perdido','contrato_firmado')) AS leads_warm,
  (SELECT COUNT(*) FROM public.leads WHERE scl_score <= 3 AND status NOT IN ('rechazado','perdido','contrato_firmado')) AS leads_cold,
  (SELECT COUNT(*) FROM public.v_leads_beneficio_pendientes) AS leads_beneficio_pendientes,
  (SELECT COUNT(*) FROM public.leads WHERE es_internacional = TRUE AND status NOT IN ('rechazado','perdido','contrato_firmado')) AS leads_internacionales,
  (SELECT COUNT(*) FROM public.viewings WHERE fecha_hora::DATE = CURRENT_DATE) AS viewings_hoy,
  (SELECT COUNT(*) FROM public.contracts WHERE estado = 'activo') AS contratos_activos,
  (SELECT COUNT(*) FROM public.properties WHERE estado IN ('available','void')) AS propiedades_void;

-- -----------------------------------------------------------------------------
-- 1h. Actualizar v_leads_dormantes (añadir scl_score)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW public.v_leads_dormantes AS
SELECT
  l.id, l.nombre, l.telefono, l.canal_origen,
  l.zona_preferida, l.presupuesto_max, l.tipo_propiedad,
  l.urgency_score, l.scl_score, l.data_completeness, l.budget_fit,
  l.asignado_a, l.pipeline_stage,
  l.ultima_interaccion AT TIME ZONE 'Europe/London' AS ultima_interaccion_london,
  EXTRACT(DAY FROM (NOW() - l.ultima_interaccion))::INTEGER AS dias_sin_contacto
FROM public.leads l
WHERE l.status NOT IN ('rechazado','perdido','contrato_firmado')
  AND l.ultima_interaccion < NOW() - INTERVAL '7 days'
ORDER BY l.ultima_interaccion ASC;
