-- =============================================================================
-- Migración: Añadir función para archivar leads de forma segura
-- RentInLondon PRO
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_archive_lead(p_lead_id UUID, p_motivo TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Actualizar el lead a estado 'lost' y guardar el motivo en notas
    UPDATE public.leads
    SET 
        pipeline_stage = 'lost',
        status = 'perdido',
        notas = COALESCE(notas, '') || E'\n[ARCHIVADO]: ' || p_motivo,
        updated_at = NOW()
    WHERE id = p_lead_id;
END;
$$;

COMMENT ON FUNCTION public.fn_archive_lead(UUID, TEXT) IS 'Archiva un lead moviéndolo al estado perdido. Uso preferido sobre DELETE físico.';
