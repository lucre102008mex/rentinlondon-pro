-- =============================================================================
-- RentInLondon PRO — Migración 00002: Datos de zonas de Londres
-- 30+ zonas reales con rangos de precios en GBP/mes (2024-2025)
-- Fuente: Rightmove, Zoopla, Gumtree market data
-- =============================================================================

-- Limpiar datos de muestra de la migración anterior
DELETE FROM public.zone_ranges WHERE descripcion LIKE 'Sample data%';

-- =============================================================================
-- ZONA 1 — CENTRAL LONDON (Zonas 1-2)
-- =============================================================================

INSERT INTO public.zone_ranges (zona, zona_postal, zona_tube, room_min, room_max, studio_min, studio_max, bed1_min, bed1_max, bed2_min, bed2_max, descripcion) VALUES
('City of London',    'EC1-EC4',  1, 1100, 1500, 1800, 2400, 2400, 3200, 3500, 5000, 'The Square Mile - finanzas, bancos, seguros'),
('Canary Wharf',      'E14',      2, 1000, 1400, 1600, 2200, 2200, 3000, 3200, 4500, 'Nuevo centro financiero, HSBC, Barclays'),
('Westminster',       'SW1',      1, 1200, 1700, 2000, 2800, 2800, 3800, 4000, 6000, 'Zona gubernamental, muy céntrica'),
('Soho/Covent Garden','WC2/W1',   1, 1300, 1800, 2200, 3000, 3000, 4200, 4500, 6500, 'Entretenimiento, restaurantes, teatro'),
('Marylebone',        'W1',       1, 1400, 1900, 2400, 3200, 3200, 4500, 4500, 7000, 'Exclusivo, boutiques, clínicas'),
('Mayfair',           'W1',       1, 1800, 2500, 3000, 4500, 4500, 6500, 6000, 10000,'Ultrapremium, embajadas, hoteles 5 estrellas'),
('Knightsbridge',     'SW3/SW7',  1, 1700, 2400, 2800, 4000, 4000, 6000, 5500, 9000, 'Harrods, South Kensington, museos'),
('Chelsea',           'SW3',      2, 1400, 2000, 2200, 3200, 3200, 4500, 4500, 7000, 'Trendy, King''s Road, río Támesis'),
('Kensington',        'W8/W14',   2, 1300, 1900, 2000, 3000, 3000, 4200, 4200, 6500, 'Embajadas, parques, museo V&A'),
('Notting Hill',      'W11',      2, 1200, 1800, 1800, 2700, 2700, 3800, 3800, 5800, 'Bohemio, mercado Portobello, famoso en cine'),

-- =============================================================================
-- ZONA 2 — NORTH LONDON
-- =============================================================================
('Camden',            'NW1',      2, 900,  1300, 1400, 1900, 1900, 2500, 2700, 3800, 'Alternativo, mercado de Camden, jóvenes'),
('Islington',         'N1',       2, 950,  1350, 1500, 2000, 2000, 2700, 2800, 4000, 'Upper Street, Angel, profesionales'),
('Hackney',           'E8/E9',    2, 800,  1200, 1200, 1700, 1700, 2300, 2400, 3500, 'Trendy en auge, Broadway Market'),
('Dalston',           'E8',       2, 750,  1100, 1100, 1600, 1600, 2200, 2200, 3200, 'Clubs nocturnos, restaurantes, vibrante'),
('Stoke Newington',   'N16',      3, 750,  1100, 1150, 1650, 1650, 2200, 2300, 3300, 'Familiar, café culture, Church Street'),
('Highbury',          'N5',       2, 850,  1250, 1300, 1800, 1800, 2400, 2500, 3600, 'Cerca Emirates Stadium, tranquilo'),
('Crouch End',        'N8',       NULL,700, 1050, 1100, 1550, 1550, 2100, 2200, 3200, 'Sin tube directo, bus, artístico'),
('Tottenham',         'N17',      3, 600,  900,  950,  1350, 1350, 1850, 1900, 2800, 'Asequible, en regeneración'),
('Finsbury Park',     'N4',       2, 750,  1100, 1150, 1600, 1600, 2200, 2300, 3200, 'Nodo de transporte, multicultural'),
('Muswell Hill',      'N10',      NULL,700, 1050, 1100, 1550, 1550, 2100, 2200, 3100, 'Residencial, vistas al sur, sin tube'),

-- =============================================================================
-- ZONA 3 — EAST LONDON
-- =============================================================================
('Shoreditch',        'E1',       2, 950,  1350, 1500, 2100, 2100, 2800, 2900, 4200, 'Tech hub, street art, Brick Lane'),
('Bethnal Green',     'E2',       2, 800,  1200, 1250, 1750, 1750, 2350, 2400, 3500, 'East End clásico, mejorando'),
('Stratford',         'E15',      3, 700,  1050, 1100, 1550, 1550, 2100, 2200, 3200, 'Westfield, olimpiadas 2012, asequible'),
('Walthamstow',       'E17',      3, 650,  950,  1000, 1450, 1450, 1950, 1950, 2850, 'Cadena de cafeterías, mercado histórico'),
('Bow',               'E3',       2, 750,  1100, 1150, 1600, 1600, 2200, 2200, 3200, 'Bien conectado, asequible para Zone 2'),

-- =============================================================================
-- ZONA 4 — SOUTH LONDON
-- =============================================================================
('Brixton',           'SW2/SW9',  2, 800,  1200, 1250, 1750, 1750, 2350, 2400, 3500, 'Multicultural, vibrante, mercado cubierto'),
('Clapham',           'SW4',      2, 900,  1300, 1400, 1950, 1950, 2650, 2700, 3900, 'Jóvenes profesionales, Clapham Common'),
('Peckham',           'SE15',     2, 700,  1050, 1100, 1550, 1550, 2100, 2200, 3200, 'Artístico en auge, Bussey Building'),
('Lewisham',          'SE13',     3, 650,  950,  1000, 1400, 1400, 1900, 1900, 2750, 'Transporte DLR, asequible'),
('Greenwich',         'SE10',     3, 700,  1050, 1100, 1550, 1550, 2100, 2200, 3200, 'Histórico, mercado, Cutty Sark'),
('Bermondsey',        'SE1',      1, 1000, 1450, 1600, 2200, 2200, 3000, 3100, 4500, 'Near London Bridge, revalorizado'),

-- =============================================================================
-- ZONA 5 — WEST LONDON
-- =============================================================================
('Shepherd''s Bush',  'W12',      2, 850,  1250, 1350, 1900, 1900, 2550, 2600, 3800, 'Westfield shopping, buena conexión'),
('Hammersmith',       'W6',       2, 900,  1300, 1450, 2000, 2000, 2700, 2800, 4000, 'Bien conectado, zona de oficinas'),
('Ealing',            'W5',       3, 750,  1100, 1150, 1650, 1650, 2250, 2350, 3400, 'Familiar, Elizabeth Line, tranquilo');

-- =============================================================================
-- Verificación post-inserción
-- =============================================================================
DO $$
DECLARE
  zona_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO zona_count FROM public.zone_ranges;
  RAISE NOTICE 'Zone ranges insertadas: % zonas', zona_count;
  IF zona_count < 30 THEN
    RAISE WARNING 'Se esperaban al menos 30 zonas, se encontraron: %', zona_count;
  END IF;
END;
$$;
