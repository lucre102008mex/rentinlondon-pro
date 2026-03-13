// Script para insertar el lead Yusuf en la base de datos de Supabase
// Requiere la SUPABASE_SERVICE_ROLE_KEY del archivo .env

const SUPABASE_URL = 'https://tiwwthopkvtngpyhchbx.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'completar_en_produccion';

async function insertLead() {
    const leadData = {
        nombre: 'Yusuf',
        canal_origen: 'whatsapp',
        zona_preferida: 'North London',
        tipo_propiedad: 'studio',
        presupuesto_min: 700,
        presupuesto_max: 800,
        fecha_mudanza: '2026-04-11',
        duracion_contrato_meses: 6,
        status: 'nuevo',
        pipeline_stage: 'intake',
        asignado_a: 'jeanette',
        es_internacional: false,
        urgency_score: 3,
        data_completeness: 0.57,
        budget_fit: 'unknown',
        notas: 'Cliente estudiante con guarantor. Contactado vía WhatsApp. Busca flat para sí mismo en North London con presupuesto £700-800.',
        lead_origin_details: {
            contact_method: 'whatsapp',
            conversation_date: '2026-03-11',
            agent: 'Jeanette',
            guarantor: 'yes',
            employment: 'student'
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
            const error = await response.text();
            throw new Error(`Error ${response.status}: ${error}`);
        }

        console.log('Lead Yusuf insertado correctamente.');
    } catch (error) {
        console.error('Error al insertar el lead:', error.message);
    }
}

insertLead();