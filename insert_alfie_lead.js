// Script para insertar el lead Alfie Kingsnorth en Supabase
// Requiere la SUPABASE_SERVICE_ROLE_KEY del archivo .env

const SUPABASE_URL = 'https://tiwwthopkvtngpyhchbx.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'REPLACE_WITH_YOUR_SERVICE_ROLE_KEY';

async function insertLead() {
    const leadData = {
        nombre: 'Alfie Kingsnorth',
        canal_origen: 'whatsapp',
        zona_preferida: 'South London',
        tipo_propiedad: 'studio',
        presupuesto_min: 900,
        presupuesto_max: 1100,
        fecha_mudanza: '2026-05-01',
        duracion_contrato_meses: 6,
        status: 'nuevo',
        pipeline_stage: 'intake',
        asignado_a: 'ivy',
        es_internacional: false,
        urgency_score: 2,
        data_completeness: 0.5,
        budget_fit: 'unknown',
        notas: 'Lead potencial sin detalles adicionales. Contactado vía WhatsApp.',
        lead_origin_details: {
            contact_method: 'whatsapp',
            conversation_date: '2026-03-13',
            agent: 'Ivy'
        }
    };

    try {
        const response = await fetch(`${SUPABASE_URL}/rest/v1/leads`, {
            method: 'POST',
            headers: {
                'apikey': SUPABASE_SERVICE_ROLE_KEY,
                'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
                'Content-Type': 'application/json',
                'Prefer': 'return=minimal'
            },
            body: JSON.stringify(leadData)
        });
        if (!response.ok) {
            const err = await response.text();
            throw new Error(`Error ${response.status}: ${err}`);
        }
        console.log('Lead Alfie Kingsnorth insertado correctamente.');
    } catch (e) {
        console.error('Error al insertar el lead:', e.message);
    }
}

insertLead();