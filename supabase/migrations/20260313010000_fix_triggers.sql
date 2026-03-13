-- =============================================================================
-- Migración 00006b: Fix triggers y score history
-- =============================================================================

-- 1. Primero verificamos que las columnas existan y el trigger pueda aplicarse
-- El trigger trg_leads_score_history necesita que scl_score exista (ya existe)

-- 2. Crear la función de score history (separada para evitar errores)
CREATE OR REPLACE FUNCTION public.fn_record_score_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Solo registrar si el score cambió y ambos valores no son nulos
    IF NEW.scl_score IS DISTINCT FROM OLD.scl_score THEN
        INSERT INTO public.lead_score_history
            (lead_id, scl_score_anterior, scl_score_nuevo, cambio_score, factor_cambio, detalle_cambio)
        VALUES
            (NEW.id, OLD.scl_score, NEW.scl_score, 
             COALESCE(NEW.scl_score, 0) - COALESCE(OLD.scl_score, 0),
             'auto',
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

-- 3. Crear el trigger (solo si la tabla lead_score_history existe)
DO $$
BEGIN
    -- Verificar que la tabla existe
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'lead_score_history') THEN
        -- Eliminar trigger existente si hay
        DROP TRIGGER IF EXISTS trg_leads_score_history ON public.leads;
        
        -- Crear trigger
        CREATE TRIGGER trg_leads_score_history
            AFTER UPDATE OF scl_score ON public.leads
            FOR EACH ROW
            EXECUTE FUNCTION public.fn_record_score_change();
    END IF;
END $$;

-- 4. Verificar triggers existentes en leads
SELECT tgname, proname 
FROM pg_trigger t 
JOIN pg_proc p ON t.tgfoid = p.oid 
WHERE tgrelid = 'public.leads'::regclass;