-- Insertar lead Yusuf en la tabla leads
-- Datos extraídos de la conversación de WhatsApp con Jeanette el 11/03/2026

INSERT INTO public.leads (
    nombre,
    canal_origen,
    zona_preferida,
    tipo_propiedad,
    presupuesto_min,
    presupuesto_max,
    fecha_mudanza,
    duracion_contrato_meses,
    status,
    pipeline_stage,
    asignado_a,
    es_internacional,
    urgency_score,
    data_completeness,
    budget_fit,
    notas,
    lead_origin_details
) VALUES (
    'Yusuf',
    'whatsapp',
    'North London',
    'studio',
    700,
    800,
    CURRENT_DATE + INTERVAL '1 month',
    6,
    'nuevo',
    'intake',
    'jeanette',
    FALSE,
    3,
    0.57,
    'unknown',
    'Cliente estudiante con guarantor. Contactado vía WhatsApp. Busca flat para sí mismo en North London con presupuesto £700-800.',
    '{"contact_method": "whatsapp", "conversation_date": "2026-03-11", "agent": "Jeanette", "guarantor": "yes", "employment": "student"}'::JSONB
)
ON CONFLICT (nombre) DO NOTHING;