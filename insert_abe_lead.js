// Script para insertar el lead Abe en Supabase
const SUPABASE_URL = 'https://tiwwthopkvtngpyhchbx.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

async function insertLead() {
    const leadData = {
        nombre: 'Abe',
        canal_origen: 'whatsapp',
        zona_preferida: 'Stratford',
        tipo_propiedad: '1bed',
        presupuesto_min: 1300,
        presupuesto_max: 1500,
        fecha_mudanza: '2026-05-15',
        status: 'nuevo',
        pipeline_stage: 'nurturing',
        asignado_a: 'jeanette',
        notas: 'Abogado, buscando cerca de Stratford. No urgente. Presupuesto 1500.',
        lead_origin_details: { contact_method: 'whatsapp', occupation: 'lawyer', urgency: 'low' }
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
        if (!response.ok) throw new Error(await response.text());
        console.log('Lead Abe insertado correctamente.');
    } catch (e) {
        console.error(e.message);
    }
}
insertLead();