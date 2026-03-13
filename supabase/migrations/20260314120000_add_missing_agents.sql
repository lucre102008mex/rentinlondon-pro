-- =============================================================================
-- Migración 20260314120000: Añadir agentes faltantes al registro
-- =============================================================================

INSERT INTO public.agents_registry (email, agent_id, role)
VALUES 
    ('facebook@rentinlondon.com', 'facebook', 'agent'),
    ('gumtree@rentinlondon.com',  'gumtree',  'agent'),
    ('script@rentinlondon.com',   'script',   'agent')
ON CONFLICT (email) DO UPDATE SET
    agent_id = EXCLUDED.agent_id,
    role = EXCLUDED.role;
