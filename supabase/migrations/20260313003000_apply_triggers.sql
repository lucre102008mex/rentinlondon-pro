-- =============================================================================
-- Migración 00005b: [CONSOLIDADA] - Solo Sincronización de Datos Existentes
-- Las definiciones de funciones y triggers se movieron a 00005_bookings_followups.sql
-- =============================================================================

-- CREACIÓN DE FOLLOW-UPS PARA LEADS EXISTENTES (Migration Data Sync)
-- Solo crea si no existen ya followups pendientes para esos leads.

INSERT INTO public.lead_followups
    (lead_id, agente_asignado, fecha_mudanza_original, dias_antes, fecha_seguimiento, tipo_seguimiento)
SELECT 
    l.id,
    COALESCE(l.asignado_a, 'ivy'),
    l.fecha_mudanza,
    15,
    l.fecha_mudanza - INTERVAL '15 days',
    'recordatorio_mudanza'
FROM public.leads l
WHERE l.fecha_mudanza IS NOT NULL 
AND l.fecha_mudanza > CURRENT_DATE
AND NOT EXISTS (
    SELECT 1 FROM public.lead_followups f 
    WHERE f.lead_id = l.id AND f.dias_antes = 15 AND f.estado = 'pendiente'
) ON CONFLICT DO NOTHING;

INSERT INTO public.lead_followups
    (lead_id, agente_asignado, fecha_mudanza_original, dias_antes, fecha_seguimiento, tipo_seguimiento)
SELECT 
    l.id,
    COALESCE(l.asignado_a, 'ivy'),
    l.fecha_mudanza,
    7,
    l.fecha_mudanza - INTERVAL '7 days',
    'recordatorio_mudanza'
FROM public.leads l
WHERE l.fecha_mudanza IS NOT NULL 
AND l.fecha_mudanza > CURRENT_DATE
AND NOT EXISTS (
    SELECT 1 FROM public.lead_followups f 
    WHERE f.lead_id = l.id AND f.dias_antes = 7 AND f.estado = 'pendiente'
) ON CONFLICT DO NOTHING;

INSERT INTO public.lead_followups
    (lead_id, agente_asignado, fecha_mudanza_original, dias_antes, fecha_seguimiento, tipo_seguimiento)
SELECT 
    l.id,
    COALESCE(l.asignado_a, 'ivy'),
    l.fecha_mudanza,
    3,
    l.fecha_mudanza - INTERVAL '3 days',
    'recordatorio_mudanza'
FROM public.leads l
WHERE l.fecha_mudanza IS NOT NULL 
AND l.fecha_mudanza > CURRENT_DATE
AND NOT EXISTS (
    SELECT 1 FROM public.lead_followups f 
    WHERE f.lead_id = l.id AND f.dias_antes = 3 AND f.estado = 'pendiente'
) ON CONFLICT DO NOTHING;