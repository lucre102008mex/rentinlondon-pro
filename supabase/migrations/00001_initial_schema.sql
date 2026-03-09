-- =============================================================================
-- RentInLondon PRO — Migración 00001: Schema inicial completo
-- Timezone: Europe/London
-- Compliance: UK Equality Act 2010 + GDPR
-- =============================================================================

-- ─── Extensiones ─────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- =============================================================================
-- TABLA: leads
-- Fuente principal de información de prospectos
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.leads (
  id                        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Datos de contacto (GDPR: mínimos necesarios)
  nombre                    TEXT NOT NULL,
  telefono                  TEXT,
  email                     TEXT,
  canal_origen              TEXT NOT NULL DEFAULT 'whatsapp'
                              CHECK (canal_origen IN ('whatsapp','facebook','gumtree','rightmove','zoopla','spareroom','referido','web','otro')),

  -- Preferencias de búsqueda
  zona_preferida            TEXT,
  zonas_alternativas        TEXT[],
  presupuesto_min           INTEGER CHECK (presupuesto_min >= 0),
  presupuesto_max           INTEGER CHECK (presupuesto_max >= 0),
  tipo_propiedad            TEXT CHECK (tipo_propiedad IN ('room','studio','1bed','2bed','3bed','4bed+','cualquiera')),
  fecha_mudanza             DATE,
  duracion_contrato_meses   INTEGER DEFAULT 6 CHECK (duracion_contrato_meses > 0),

  -- Estado del pipeline
  status                    TEXT NOT NULL DEFAULT 'nuevo'
                              CHECK (status IN ('nuevo','contactado','calificado','viewing_programado','viewing_realizado','negociacion','contrato_enviado','contrato_firmado','rechazado','perdido','dormido')),
  pipeline_stage            TEXT NOT NULL DEFAULT 'intake'
                              CHECK (pipeline_stage IN ('intake','nurturing','viewing','closing','signed','lost')),

  -- Asignación de agente
  asignado_a                TEXT NOT NULL DEFAULT 'ivy'
                              CHECK (asignado_a IN ('alex','ivy','rose','salo','jeanette','ads-fb','ads-gumtree','script-runner','human')),

  -- Clasificación geográfica
  es_internacional          BOOLEAN NOT NULL DEFAULT FALSE,
  pais_origen               TEXT,
  requiere_right_to_rent    BOOLEAN DEFAULT FALSE,
  documentacion_enviada     BOOLEAN DEFAULT FALSE,

  -- Scoring sin sesgo (UK Equality Act 2010 compliant)
  -- Basado ÚNICAMENTE en urgencia, completitud y ajuste de presupuesto
  urgency_score             SMALLINT DEFAULT 0 CHECK (urgency_score BETWEEN 0 AND 5),
  data_completeness         NUMERIC(3,2) DEFAULT 0.00 CHECK (data_completeness BETWEEN 0.00 AND 1.00),
  budget_fit                TEXT DEFAULT 'unknown' CHECK (budget_fit IN ('good','maybe','poor','unknown')),
  response_speed_minutes    INTEGER CHECK (response_speed_minutes >= 0),

  -- Escalamiento
  escalado_jeanette         BOOLEAN DEFAULT FALSE,
  escalado_at               TIMESTAMPTZ,
  motivo_escalado           TEXT,

  -- Interacciones
  ultima_interaccion        TIMESTAMPTZ DEFAULT NOW(),
  total_interacciones       INTEGER DEFAULT 0 CHECK (total_interacciones >= 0),
  primer_contacto_at        TIMESTAMPTZ DEFAULT NOW(),

  -- Origen detallado (JSONB para datos específicos del canal)
  lead_origin_details       JSONB DEFAULT '{}'::JSONB,

  -- Notas internas
  notas                     TEXT,

  -- Compliance y auditoría
  compliance_flags          TEXT[] DEFAULT ARRAY[]::TEXT[],
  risk_notes                TEXT,

  -- Metadata
  utm_source                TEXT,
  utm_medium                TEXT,
  utm_campaign              TEXT,
  referido_por              UUID REFERENCES public.leads(id) ON DELETE SET NULL
);

COMMENT ON TABLE public.leads IS 'Tabla principal de leads/prospectos. Scoring basado únicamente en urgencia, completitud y ajuste de presupuesto — UK Equality Act 2010 compliant.';
COMMENT ON COLUMN public.leads.urgency_score IS '0-5: Calculado por fecha_mudanza y response_speed. Sin atributos protegidos.';
COMMENT ON COLUMN public.leads.data_completeness IS '0.00-1.00: Ratio de campos obligatorios completados.';
COMMENT ON COLUMN public.leads.budget_fit IS 'good/maybe/poor/unknown: Comparación con zone_ranges del mercado.';

-- =============================================================================
-- TABLA: interactions
-- Historial completo de interacciones con cada lead
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.interactions (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  lead_id       UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  agente        TEXT NOT NULL CHECK (agente IN ('alex','ivy','rose','salo','jeanette','ads-fb','ads-gumtree','script-runner','human')),
  canal         TEXT NOT NULL CHECK (canal IN ('whatsapp','telegram','facebook','email','llamada','interno')),
  tipo          TEXT NOT NULL CHECK (tipo IN ('mensaje_entrante','mensaje_saliente','nota_interna','llamada_entrante','llamada_saliente','viewing_confirmado','documento_enviado','documento_recibido','escalado')),
  contenido     TEXT,
  duracion_seg  INTEGER CHECK (duracion_seg >= 0),
  metadata      JSONB DEFAULT '{}'::JSONB
);

COMMENT ON TABLE public.interactions IS 'Historial de todas las interacciones con leads.';

-- =============================================================================
-- TABLA: properties
-- Propiedades disponibles para arrendar
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.properties (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  direccion         TEXT NOT NULL,
  zona              TEXT NOT NULL,
  tipo              TEXT NOT NULL CHECK (tipo IN ('room','studio','1bed','2bed','3bed','4bed+')),
  precio_mensual    INTEGER NOT NULL CHECK (precio_mensual > 0),
  disponible_desde  DATE NOT NULL,
  disponible_hasta  DATE,
  estado            TEXT NOT NULL DEFAULT 'available'
                      CHECK (estado IN ('available','viewing','reserved','let','maintenance','void')),
  descripcion       TEXT,
  fotos_urls        TEXT[] DEFAULT ARRAY[]::TEXT[],
  amenities         TEXT[] DEFAULT ARRAY[]::TEXT[],
  bills_incluidos   BOOLEAN DEFAULT FALSE,
  deposito_semanas  SMALLINT DEFAULT 5 CHECK (deposito_semanas BETWEEN 1 AND 8),
  min_contrato_meses SMALLINT DEFAULT 6,
  acepta_dss        BOOLEAN DEFAULT FALSE,
  acepta_mascotas   BOOLEAN DEFAULT FALSE,
  geolocalizacion   JSONB DEFAULT '{}'::JSONB,
  rightmove_id      TEXT,
  zoopla_id         TEXT,
  gumtree_id        TEXT,
  notas_internas    TEXT
);

COMMENT ON TABLE public.properties IS 'Propiedades disponibles para arrendar. acepta_dss y acepta_mascotas son características objetivas de la propiedad, no criterios de discriminación de personas.';

-- =============================================================================
-- TABLA: viewings
-- Visitas a propiedades programadas y realizadas
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.viewings (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  lead_id         UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  property_id     UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  agente          TEXT NOT NULL CHECK (agente IN ('alex','ivy','rose','salo','jeanette','ads-fb','ads-gumtree','script-runner','human')),
  fecha_hora      TIMESTAMPTZ NOT NULL,
  tipo            TEXT NOT NULL DEFAULT 'presencial'
                    CHECK (tipo IN ('presencial','video_tour','virtual_360')),
  estado          TEXT NOT NULL DEFAULT 'programado'
                    CHECK (estado IN ('programado','confirmado','realizado','cancelado_lead','cancelado_agencia','no_show')),
  notas           TEXT,
  feedback        TEXT,
  video_url       TEXT
);

-- =============================================================================
-- TABLA: contracts
-- Contratos de arrendamiento
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.contracts (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  lead_id               UUID NOT NULL REFERENCES public.leads(id) ON DELETE RESTRICT,
  property_id           UUID NOT NULL REFERENCES public.properties(id) ON DELETE RESTRICT,
  agente_cierre         TEXT NOT NULL CHECK (agente_cierre IN ('jeanette','human')),
  fecha_inicio          DATE NOT NULL,
  fecha_fin             DATE NOT NULL,
  precio_mensual        INTEGER NOT NULL CHECK (precio_mensual > 0),
  deposito_pagado       INTEGER CHECK (deposito_pagado >= 0),
  estado                TEXT NOT NULL DEFAULT 'borrador'
                          CHECK (estado IN ('borrador','enviado','firmado','activo','expirado','cancelado')),
  tipo_contrato         TEXT NOT NULL DEFAULT 'ast'
                          CHECK (tipo_contrato IN ('ast','license','company_let','otro')),
  -- Right to Rent (UK legal requirement)
  r2r_verificado        BOOLEAN DEFAULT FALSE,
  r2r_verificado_at     TIMESTAMPTZ,
  r2r_tipo_doc          TEXT,
  r2r_expiry_date       DATE,
  -- Documentos
  contrato_url          TEXT,
  referencias_urls      TEXT[] DEFAULT ARRAY[]::TEXT[],
  -- Financiero
  comision_agencia      INTEGER DEFAULT 0,
  notas                 TEXT
);

COMMENT ON TABLE public.contracts IS 'Contratos de arrendamiento. Right to Rent es requerimiento legal UK obligatorio para todos.';

-- =============================================================================
-- TABLA: agent_logs
-- Log de actividad de todos los agentes de IA
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.agent_logs (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  agente        TEXT NOT NULL CHECK (agente IN ('alex','ivy','rose','salo','jeanette','ads-fb','ads-gumtree','script-runner')),
  accion        TEXT NOT NULL,
  lead_id       UUID REFERENCES public.leads(id) ON DELETE SET NULL,
  property_id   UUID REFERENCES public.properties(id) ON DELETE SET NULL,
  tokens_usados INTEGER DEFAULT 0 CHECK (tokens_usados >= 0),
  latencia_ms   INTEGER CHECK (latencia_ms >= 0),
  exito         BOOLEAN NOT NULL DEFAULT TRUE,
  error_msg     TEXT,
  metadata      JSONB DEFAULT '{}'::JSONB
);

COMMENT ON TABLE public.agent_logs IS 'Auditoría de todas las acciones de agentes IA. Inmutable por políticas RLS.';

-- =============================================================================
-- TABLA: listings_history
-- Historial de anuncios en plataformas externas
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.listings_history (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  property_id     UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  plataforma      TEXT NOT NULL CHECK (plataforma IN ('gumtree','rightmove','zoopla','spareroom','facebook','openrent','otro')),
  listing_id_ext  TEXT,
  url             TEXT,
  estado          TEXT NOT NULL DEFAULT 'activo' CHECK (estado IN ('activo','pausado','expirado','eliminado')),
  vistas          INTEGER DEFAULT 0 CHECK (vistas >= 0),
  mensajes        INTEGER DEFAULT 0 CHECK (mensajes >= 0),
  precio_listado  INTEGER CHECK (precio_listado > 0),
  fecha_inicio    DATE NOT NULL DEFAULT CURRENT_DATE,
  fecha_fin       DATE,
  costo_gbp       NUMERIC(8,2) DEFAULT 0,
  metadata        JSONB DEFAULT '{}'::JSONB
);

-- =============================================================================
-- TABLA: weekly_summaries
-- Resúmenes semanales generados por Alex
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.weekly_summaries (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  semana_inicio         DATE NOT NULL,
  semana_fin            DATE NOT NULL,
  leads_nuevos          INTEGER DEFAULT 0,
  leads_contactados     INTEGER DEFAULT 0,
  viewings_realizados   INTEGER DEFAULT 0,
  contratos_firmados    INTEGER DEFAULT 0,
  tasa_conversion       NUMERIC(5,2),
  ingresos_gbp          NUMERIC(10,2) DEFAULT 0,
  costo_ads_gbp         NUMERIC(10,2) DEFAULT 0,
  roi_ads               NUMERIC(6,2),
  tokens_totales        INTEGER DEFAULT 0,
  resumen_texto         TEXT,
  recomendaciones       TEXT,
  metadata              JSONB DEFAULT '{}'::JSONB,
  UNIQUE(semana_inicio)
);

-- =============================================================================
-- TABLA: zone_ranges
-- Rangos de precios de mercado por zona de Londres
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.zone_ranges (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  zona          TEXT NOT NULL UNIQUE,
  zona_postal   TEXT,
  zona_tube     SMALLINT CHECK (zona_tube BETWEEN 1 AND 9),
  room_min      INTEGER NOT NULL CHECK (room_min > 0),
  room_max      INTEGER NOT NULL,
  studio_min    INTEGER NOT NULL,
  studio_max    INTEGER NOT NULL,
  bed1_min      INTEGER NOT NULL,
  bed1_max      INTEGER NOT NULL,
  bed2_min      INTEGER NOT NULL,
  bed2_max      INTEGER NOT NULL,
  descripcion   TEXT,
  CONSTRAINT room_range_valid CHECK (room_max >= room_min),
  CONSTRAINT studio_range_valid CHECK (studio_max >= studio_min),
  CONSTRAINT bed1_range_valid CHECK (bed1_max >= bed1_min),
  CONSTRAINT bed2_range_valid CHECK (bed2_max >= bed2_min)
);

COMMENT ON TABLE public.zone_ranges IS 'Rangos de precios de mercado por zona de Londres. Referencia para calcular budget_fit sin sesgo.';

-- =============================================================================
-- TABLA: compliance_audit
-- Registro de auditoría para UK Equality Act 2010 y GDPR
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.compliance_audit (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  lead_id         UUID REFERENCES public.leads(id) ON DELETE SET NULL,
  agente          TEXT CHECK (agente IN ('alex','ivy','rose','salo','jeanette','ads-fb','ads-gumtree','script-runner','system')),
  evento          TEXT NOT NULL,
  decision        TEXT,
  razon           TEXT,
  datos_excluidos TEXT[],
  accion_tomada   TEXT,
  revisado_por    TEXT,
  metadata        JSONB DEFAULT '{}'::JSONB
);

COMMENT ON TABLE public.compliance_audit IS 'Auditoría de compliance: UK Equality Act 2010. Registra qué información fue excluida de decisiones de scoring.';

-- =============================================================================
-- ÍNDICES OPTIMIZADOS
-- =============================================================================

-- leads
CREATE INDEX IF NOT EXISTS idx_leads_status_score ON public.leads (status, urgency_score DESC, ultima_interaccion DESC);
CREATE INDEX IF NOT EXISTS idx_leads_internacional ON public.leads (es_internacional, escalado_jeanette, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_leads_canal_origen ON public.leads (canal_origen, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_leads_asignado ON public.leads (asignado_a, status);
CREATE INDEX IF NOT EXISTS idx_leads_fecha_mudanza ON public.leads (fecha_mudanza ASC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_leads_budget_fit ON public.leads (budget_fit, urgency_score DESC);
CREATE INDEX IF NOT EXISTS idx_leads_telefono ON public.leads USING gin (to_tsvector('simple', COALESCE(telefono, '')));

-- interactions
CREATE INDEX IF NOT EXISTS idx_interactions_lead_date ON public.interactions (lead_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_interactions_agente ON public.interactions (agente, created_at DESC);

-- properties
CREATE INDEX IF NOT EXISTS idx_properties_zona_tipo ON public.properties (zona, tipo, estado);
CREATE INDEX IF NOT EXISTS idx_properties_estado ON public.properties (estado, disponible_desde);

-- viewings
CREATE INDEX IF NOT EXISTS idx_viewings_fecha ON public.viewings (fecha_hora ASC);
CREATE INDEX IF NOT EXISTS idx_viewings_lead ON public.viewings (lead_id, estado);

-- agent_logs
CREATE INDEX IF NOT EXISTS idx_agent_logs_agente_date ON public.agent_logs (agente, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_agent_logs_lead ON public.agent_logs (lead_id, created_at DESC);

-- compliance_audit
CREATE INDEX IF NOT EXISTS idx_compliance_lead ON public.compliance_audit (lead_id, created_at DESC);

-- =============================================================================
-- TRIGGER: update_updated_at
-- =============================================================================
CREATE OR REPLACE FUNCTION public.fn_update_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_leads_updated_at
  BEFORE UPDATE ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.fn_update_updated_at();

CREATE TRIGGER trg_properties_updated_at
  BEFORE UPDATE ON public.properties
  FOR EACH ROW EXECUTE FUNCTION public.fn_update_updated_at();

CREATE TRIGGER trg_viewings_updated_at
  BEFORE UPDATE ON public.viewings
  FOR EACH ROW EXECUTE FUNCTION public.fn_update_updated_at();

CREATE TRIGGER trg_contracts_updated_at
  BEFORE UPDATE ON public.contracts
  FOR EACH ROW EXECUTE FUNCTION public.fn_update_updated_at();

CREATE TRIGGER trg_listings_updated_at
  BEFORE UPDATE ON public.listings_history
  FOR EACH ROW EXECUTE FUNCTION public.fn_update_updated_at();

-- =============================================================================
-- TRIGGER: calculate_urgency_score
-- Calcula 0-5 basado en fecha_mudanza y response_speed_minutes
-- SIN atributos protegidos — UK Equality Act 2010
-- =============================================================================
CREATE OR REPLACE FUNCTION public.fn_calculate_urgency_score()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  days_until_move INTEGER;
  score           SMALLINT := 0;
BEGIN
  -- Factor 1: Proximidad de fecha de mudanza (0-3 puntos)
  IF NEW.fecha_mudanza IS NOT NULL THEN
    days_until_move := (NEW.fecha_mudanza - CURRENT_DATE);
    IF days_until_move <= 7 THEN
      score := score + 3;
    ELSIF days_until_move <= 14 THEN
      score := score + 2;
    ELSIF days_until_move <= 30 THEN
      score := score + 1;
    END IF;
  END IF;

  -- Factor 2: Velocidad de respuesta (0-2 puntos)
  IF NEW.response_speed_minutes IS NOT NULL THEN
    IF NEW.response_speed_minutes <= 10 THEN
      score := score + 2;
    ELSIF NEW.response_speed_minutes <= 60 THEN
      score := score + 1;
    END IF;
  END IF;

  -- Asegurar rango 0-5
  NEW.urgency_score := LEAST(GREATEST(score, 0), 5);

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_leads_urgency_score
  BEFORE INSERT OR UPDATE OF fecha_mudanza, response_speed_minutes
  ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.fn_calculate_urgency_score();

-- =============================================================================
-- TRIGGER: calculate_data_completeness
-- Ratio de campos obligatorios completados (0.00-1.00)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.fn_calculate_data_completeness()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  total_fields  INTEGER := 7;
  filled_fields INTEGER := 0;
BEGIN
  -- Campos obligatorios evaluados (7 en total)
  IF NEW.nombre IS NOT NULL AND length(trim(NEW.nombre)) > 0 THEN filled_fields := filled_fields + 1; END IF;
  IF NEW.telefono IS NOT NULL AND length(trim(NEW.telefono)) > 0 THEN filled_fields := filled_fields + 1; END IF;
  IF NEW.zona_preferida IS NOT NULL AND length(trim(NEW.zona_preferida)) > 0 THEN filled_fields := filled_fields + 1; END IF;
  IF NEW.presupuesto_max IS NOT NULL AND NEW.presupuesto_max > 0 THEN filled_fields := filled_fields + 1; END IF;
  IF NEW.tipo_propiedad IS NOT NULL THEN filled_fields := filled_fields + 1; END IF;
  IF NEW.fecha_mudanza IS NOT NULL THEN filled_fields := filled_fields + 1; END IF;
  IF NEW.duracion_contrato_meses IS NOT NULL AND NEW.duracion_contrato_meses > 0 THEN filled_fields := filled_fields + 1; END IF;

  NEW.data_completeness := ROUND((filled_fields::NUMERIC / total_fields::NUMERIC), 2);

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_leads_data_completeness
  BEFORE INSERT OR UPDATE OF nombre, telefono, zona_preferida, presupuesto_max, tipo_propiedad, fecha_mudanza, duracion_contrato_meses
  ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.fn_calculate_data_completeness();

-- =============================================================================
-- TRIGGER: calculate_budget_fit
-- Compara presupuesto del lead con rangos de mercado en zone_ranges
-- =============================================================================
CREATE OR REPLACE FUNCTION public.fn_calculate_budget_fit()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  zr        RECORD;
  min_price INTEGER;
  max_price INTEGER;
BEGIN
  -- Solo calcular si tenemos zona, tipo y presupuesto
  IF NEW.zona_preferida IS NULL OR NEW.tipo_propiedad IS NULL OR NEW.presupuesto_max IS NULL THEN
    NEW.budget_fit := 'unknown';
    RETURN NEW;
  END IF;

  -- Buscar en zone_ranges
  SELECT * INTO zr FROM public.zone_ranges
  WHERE lower(zona) = lower(NEW.zona_preferida)
  LIMIT 1;

  IF NOT FOUND THEN
    NEW.budget_fit := 'unknown';
    RETURN NEW;
  END IF;

  -- Seleccionar rango según tipo de propiedad
  CASE NEW.tipo_propiedad
    WHEN 'room'   THEN min_price := zr.room_min;   max_price := zr.room_max;
    WHEN 'studio' THEN min_price := zr.studio_min; max_price := zr.studio_max;
    WHEN '1bed'   THEN min_price := zr.bed1_min;   max_price := zr.bed1_max;
    WHEN '2bed'   THEN min_price := zr.bed2_min;   max_price := zr.bed2_max;
    ELSE
      NEW.budget_fit := 'unknown';
      RETURN NEW;
  END CASE;

  -- Evaluar ajuste
  IF NEW.presupuesto_max >= min_price THEN
    IF NEW.presupuesto_max >= (min_price * 0.90)::INTEGER THEN
      NEW.budget_fit := 'good';
    ELSE
      NEW.budget_fit := 'maybe';
    END IF;
  ELSE
    IF NEW.presupuesto_max >= (min_price * 0.80)::INTEGER THEN
      NEW.budget_fit := 'maybe';
    ELSE
      NEW.budget_fit := 'poor';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_leads_budget_fit
  BEFORE INSERT OR UPDATE OF zona_preferida, tipo_propiedad, presupuesto_max
  ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.fn_calculate_budget_fit();

-- =============================================================================
-- TRIGGER: actualizar ultima_interaccion y total_interacciones
-- =============================================================================
CREATE OR REPLACE FUNCTION public.fn_update_lead_interaction_stats()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.leads SET
    ultima_interaccion  = NOW(),
    total_interacciones = total_interacciones + 1
  WHERE id = NEW.lead_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_interactions_update_lead
  AFTER INSERT ON public.interactions
  FOR EACH ROW EXECUTE FUNCTION public.fn_update_lead_interaction_stats();

-- =============================================================================
-- VISTAS — todas con AT TIME ZONE 'Europe/London'
-- =============================================================================

-- Vista: Leads activos con clasificación HOT/WARM/COLD
CREATE OR REPLACE VIEW public.v_leads_activos AS
SELECT
  l.id,
  l.nombre,
  l.telefono,
  l.canal_origen,
  l.zona_preferida,
  l.tipo_propiedad,
  l.presupuesto_max,
  l.fecha_mudanza,
  l.status,
  l.pipeline_stage,
  l.asignado_a,
  l.es_internacional,
  l.urgency_score,
  l.data_completeness,
  l.budget_fit,
  CASE
    WHEN l.urgency_score >= 4 THEN 'HOT'
    WHEN l.urgency_score >= 2 THEN 'WARM'
    ELSE 'COLD'
  END AS temperatura,
  l.ultima_interaccion AT TIME ZONE 'Europe/London' AS ultima_interaccion_london,
  l.created_at AT TIME ZONE 'Europe/London' AS created_at_london,
  EXTRACT(EPOCH FROM (NOW() - l.ultima_interaccion)) / 3600 AS horas_sin_contacto
FROM public.leads l
WHERE l.status NOT IN ('rechazado','perdido','contrato_firmado')
ORDER BY l.urgency_score DESC, l.ultima_interaccion DESC;

-- Vista: Leads dormantes (sin interacción en 7+ días)
CREATE OR REPLACE VIEW public.v_leads_dormantes AS
SELECT
  l.id,
  l.nombre,
  l.telefono,
  l.canal_origen,
  l.zona_preferida,
  l.presupuesto_max,
  l.status,
  l.asignado_a,
  l.urgency_score,
  l.data_completeness,
  l.ultima_interaccion AT TIME ZONE 'Europe/London' AS ultima_interaccion_london,
  l.created_at AT TIME ZONE 'Europe/London' AS created_at_london,
  ROUND(EXTRACT(EPOCH FROM (NOW() - l.ultima_interaccion)) / 86400) AS dias_sin_contacto
FROM public.leads l
WHERE
  l.ultima_interaccion < NOW() - INTERVAL '7 days'
  AND l.status NOT IN ('rechazado','perdido','contrato_firmado','dormido')
ORDER BY l.ultima_interaccion ASC;

-- Vista: Propiedades disponibles sin leads asignados (void)
CREATE OR REPLACE VIEW public.v_propiedades_void AS
SELECT
  p.id,
  p.direccion,
  p.zona,
  p.tipo,
  p.precio_mensual,
  p.disponible_desde AT TIME ZONE 'Europe/London' AS disponible_desde_london,
  CURRENT_DATE - p.disponible_desde AS dias_void,
  p.bills_incluidos,
  p.deposito_semanas,
  p.estado,
  (
    SELECT COUNT(*)
    FROM public.viewings v
    WHERE v.property_id = p.id AND v.estado IN ('programado','confirmado')
  ) AS viewings_pendientes
FROM public.properties p
WHERE p.estado IN ('available','void')
ORDER BY p.disponible_desde ASC;

-- Vista: Resumen diario para Alex
CREATE OR REPLACE VIEW public.v_daily_summary AS
SELECT
  (CURRENT_DATE AT TIME ZONE 'Europe/London')::DATE AS fecha_london,
  (SELECT COUNT(*) FROM public.leads WHERE created_at::DATE = CURRENT_DATE) AS leads_nuevos_hoy,
  (SELECT COUNT(*) FROM public.leads WHERE status NOT IN ('rechazado','perdido','contrato_firmado')) AS leads_activos_total,
  (SELECT COUNT(*) FROM public.leads WHERE urgency_score >= 4 AND status NOT IN ('rechazado','perdido','contrato_firmado')) AS leads_hot,
  (SELECT COUNT(*) FROM public.leads WHERE urgency_score BETWEEN 2 AND 3 AND status NOT IN ('rechazado','perdido','contrato_firmado')) AS leads_warm,
  (SELECT COUNT(*) FROM public.leads WHERE urgency_score <= 1 AND status NOT IN ('rechazado','perdido','contrato_firmado')) AS leads_cold,
  (SELECT COUNT(*) FROM public.leads WHERE es_internacional = TRUE AND status NOT IN ('rechazado','perdido','contrato_firmado')) AS leads_internacionales,
  (SELECT COUNT(*) FROM public.viewings WHERE fecha_hora::DATE = CURRENT_DATE) AS viewings_hoy,
  (SELECT COUNT(*) FROM public.contracts WHERE estado = 'activo') AS contratos_activos,
  (SELECT COUNT(*) FROM public.properties WHERE estado IN ('available','void')) AS propiedades_void,
  (SELECT COUNT(*) FROM public.leads WHERE ultima_interaccion < NOW() - INTERVAL '7 days' AND status NOT IN ('rechazado','perdido','contrato_firmado','dormido')) AS leads_dormantes,
  (SELECT SUM(tokens_usados) FROM public.agent_logs WHERE created_at::DATE = CURRENT_DATE) AS tokens_usados_hoy,
  NOW() AT TIME ZONE 'Europe/London' AS generado_at_london;

-- Vista: Reporte de compliance
CREATE OR REPLACE VIEW public.v_compliance_report AS
SELECT
  ca.id,
  ca.created_at AT TIME ZONE 'Europe/London' AS created_at_london,
  ca.lead_id,
  l.nombre AS lead_nombre,
  ca.agente,
  ca.evento,
  ca.decision,
  ca.razon,
  ca.datos_excluidos,
  ca.accion_tomada,
  ca.revisado_por
FROM public.compliance_audit ca
LEFT JOIN public.leads l ON ca.lead_id = l.id
ORDER BY ca.created_at DESC;

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.viewings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agent_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.listings_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.zone_ranges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compliance_audit ENABLE ROW LEVEL SECURITY;

-- ─── Política base: service_role tiene acceso completo ────────────────────────
CREATE POLICY "service_role_all" ON public.leads FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON public.interactions FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON public.properties FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON public.viewings FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON public.contracts FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON public.agent_logs FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON public.listings_history FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON public.weekly_summaries FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON public.zone_ranges FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON public.compliance_audit FOR ALL USING (auth.role() = 'service_role');

-- ─── Alex: lectura amplia, escritura en reportes y logs ───────────────────────
CREATE POLICY "alex_read_leads" ON public.leads
  FOR SELECT USING (auth.jwt() ->> 'agent_id' = 'alex');

CREATE POLICY "alex_read_interactions" ON public.interactions
  FOR SELECT USING (auth.jwt() ->> 'agent_id' = 'alex');

CREATE POLICY "alex_insert_logs" ON public.agent_logs
  FOR INSERT WITH CHECK (auth.jwt() ->> 'agent_id' = 'alex');

CREATE POLICY "alex_insert_summaries" ON public.weekly_summaries
  FOR ALL USING (auth.jwt() ->> 'agent_id' = 'alex');

CREATE POLICY "alex_read_compliance" ON public.compliance_audit
  FOR SELECT USING (auth.jwt() ->> 'agent_id' = 'alex');

-- ─── Ivy: leads UK + interactions ────────────────────────────────────────────
CREATE POLICY "ivy_leads_uk" ON public.leads
  FOR ALL USING (
    auth.jwt() ->> 'agent_id' = 'ivy'
    AND (es_internacional = FALSE OR asignado_a = 'ivy')
  );

CREATE POLICY "ivy_interactions" ON public.interactions
  FOR ALL USING (auth.jwt() ->> 'agent_id' = 'ivy');

CREATE POLICY "ivy_logs" ON public.agent_logs
  FOR INSERT WITH CHECK (auth.jwt() ->> 'agent_id' = 'ivy');

-- ─── Rose: leads UK de ads + interactions ────────────────────────────────────
CREATE POLICY "rose_leads_uk" ON public.leads
  FOR ALL USING (
    auth.jwt() ->> 'agent_id' = 'rose'
    AND es_internacional = FALSE
    AND canal_origen IN ('facebook','instagram','ads')
  );

CREATE POLICY "rose_interactions" ON public.interactions
  FOR ALL USING (auth.jwt() ->> 'agent_id' = 'rose');

CREATE POLICY "rose_logs" ON public.agent_logs
  FOR INSERT WITH CHECK (auth.jwt() ->> 'agent_id' = 'rose');

-- ─── Salo: leads UK de marketplaces + interactions ───────────────────────────
CREATE POLICY "salo_leads_uk" ON public.leads
  FOR ALL USING (
    auth.jwt() ->> 'agent_id' = 'salo'
    AND es_internacional = FALSE
    AND canal_origen IN ('gumtree','rightmove','zoopla','spareroom','openrent')
  );

CREATE POLICY "salo_interactions" ON public.interactions
  FOR ALL USING (auth.jwt() ->> 'agent_id' = 'salo');

CREATE POLICY "salo_logs" ON public.agent_logs
  FOR INSERT WITH CHECK (auth.jwt() ->> 'agent_id' = 'salo');

-- ─── Jeanette: leads UK e internacionales + contratos ────────────────────────
CREATE POLICY "jeanette_leads" ON public.leads
  FOR ALL USING (
    auth.jwt() ->> 'agent_id' = 'jeanette'
    AND (es_internacional = TRUE OR asignado_a = 'jeanette' OR escalado_jeanette = TRUE)
  );

CREATE POLICY "jeanette_contracts" ON public.contracts
  FOR ALL USING (auth.jwt() ->> 'agent_id' = 'jeanette');

CREATE POLICY "jeanette_interactions" ON public.interactions
  FOR ALL USING (auth.jwt() ->> 'agent_id' = 'jeanette');

CREATE POLICY "jeanette_logs" ON public.agent_logs
  FOR INSERT WITH CHECK (auth.jwt() ->> 'agent_id' = 'jeanette');

-- ─── ads-fb: solo INSERT de leads de Facebook ─────────────────────────────────
CREATE POLICY "ads_fb_insert_leads" ON public.leads
  FOR INSERT WITH CHECK (
    auth.jwt() ->> 'agent_id' = 'ads-fb'
    AND canal_origen = 'facebook'
  );

CREATE POLICY "ads_fb_select_own" ON public.leads
  FOR SELECT USING (
    auth.jwt() ->> 'agent_id' = 'ads-fb'
    AND canal_origen = 'facebook'
  );

CREATE POLICY "ads_fb_logs" ON public.agent_logs
  FOR INSERT WITH CHECK (auth.jwt() ->> 'agent_id' = 'ads-fb');

-- ─── ads-gumtree: solo INSERT de leads de marketplaces ───────────────────────
CREATE POLICY "ads_gumtree_insert_leads" ON public.leads
  FOR INSERT WITH CHECK (
    auth.jwt() ->> 'agent_id' = 'ads-gumtree'
    AND canal_origen IN ('gumtree','rightmove','zoopla','spareroom','openrent')
  );

CREATE POLICY "ads_gumtree_select_own" ON public.leads
  FOR SELECT USING (
    auth.jwt() ->> 'agent_id' = 'ads-gumtree'
    AND canal_origen IN ('gumtree','rightmove','zoopla','spareroom','openrent')
  );

CREATE POLICY "ads_gumtree_listings" ON public.listings_history
  FOR ALL USING (auth.jwt() ->> 'agent_id' = 'ads-gumtree');

CREATE POLICY "ads_gumtree_logs" ON public.agent_logs
  FOR INSERT WITH CHECK (auth.jwt() ->> 'agent_id' = 'ads-gumtree');

-- ─── script-runner: solo vistas y logs, sin canales externos ─────────────────
CREATE POLICY "script_runner_read" ON public.leads
  FOR SELECT USING (auth.jwt() ->> 'agent_id' = 'script-runner');

CREATE POLICY "script_runner_update_status" ON public.leads
  FOR UPDATE USING (auth.jwt() ->> 'agent_id' = 'script-runner')
  WITH CHECK (auth.jwt() ->> 'agent_id' = 'script-runner');

CREATE POLICY "script_runner_logs" ON public.agent_logs
  FOR INSERT WITH CHECK (auth.jwt() ->> 'agent_id' = 'script-runner');

-- ─── Lectura pública de zone_ranges (sin datos sensibles) ────────────────────
CREATE POLICY "public_read_zones" ON public.zone_ranges
  FOR SELECT USING (TRUE);

-- =============================================================================
-- DATOS INICIALES: Insertar zona sample para verificar triggers
-- =============================================================================
INSERT INTO public.zone_ranges (zona, zona_postal, zona_tube, room_min, room_max, studio_min, studio_max, bed1_min, bed1_max, bed2_min, bed2_max, descripcion)
VALUES ('Camden', 'NW1', 2, 900, 1300, 1400, 1800, 1800, 2400, 2600, 3200, 'Sample data - ver migración 00002 para datos completos')
ON CONFLICT (zona) DO NOTHING;
