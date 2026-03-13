// Script para insertar el lead Abisola Famurewa en Supabase
// Requiere la SUPABASE_SERVICE_ROLE_KEY del archivo .env

const SUPABASE_URL = 'https://tiwwthopkvtngpyhchbx.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'REPLACE_WITH_YOUR_SERVICE_ROLE_KEY';

async function insertLead() {
    const leadData = {
        nombre: 'Abisola Famurewa',
        canal_origen: 'whatsapp',
        zona_preferida: 'East London',
        tipo_propiedad: '1bed',
        presupuesto_min: 1200,
        presupuesto_max: 1500,
        fecha_mudanza: '2026-04-20',
        duracion_contrato_meses: 6,
        status: 'nuevo',
        pipeline_stage: 'intake',
        asignado_a: 'ivy',
        es_internacional: false,
        urgency_score: 3,
        data_completeness: 0.55,
        budget_fit: 'unknown',
        notas: 'Lead potencial interesado en 1bed. Contactado vía WhatsApp.',
        lead_origin_details: {
            contact_method: 'whatsapp',
            conversation_date: '2026-03-14',
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
        console.log('Lead Abisola Famurewa insertado correctamente.');
    } catch (e) {
        console.error('Error al insertar el lead:', e.message);
    }
}

insertLead();