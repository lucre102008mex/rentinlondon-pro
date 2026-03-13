# Guía de Bookings (Citas en Oficina)

## Visión General
La tabla `public.bookings` gestiona citas confirmadas en la oficina (154 Bishopsgate, London EC2M 4LN) para leads UK que confirmaron asistencia presencial.

## Estructura de Datos
```sql
CREATE TABLE public.bookings (
  id UUID PRIMARY KEY,
  lead_id UUID REFERENCES public.leads(id),
  agente_asignado TEXT,  -- ivy, rose, salo, jeanette, human
  fecha_cita DATE,
  hora_cita TIME,
  tipo TEXT,  -- presencial, hibrido, video_tour
  estado TEXT,  -- programado, confirmado, completado, cancelado, no_show, reagendado
  notas TEXT
);
```

## Flujo de Trabajo Correcto

1. **Lead en proceso de coordinación** → Pipeline Stage: `nurturing`
2. **Lead confirma visita a oficina** → Crear registro en `public.bookings`
3. **Lead visita propiedad específica** → Crear registro en `public.viewings`
4. **Después de visita** → Actualizar lead según resultado:
   - Si le gusta propiedad → `closing`
   - Si necesita más opciones → `nurturing`
   - Si no continúa → `lost`

## Ejemplos de Uso

### Crear Booking desde Conversación
```bash
POST /rest/v1/bookings
{
  "lead_id": "uuid_del_lead",
  "fecha_cita": "2026-03-23",
  "hora_cita": "11:00",
  "agente_asignado": "jeanette",
  "estado": "programado",
  "tipo": "presencial",
  "notas": "Visita para verificar propiedades SW London"
}
```

### Consultar Bookings de Hoy
```bash
GET /rest/v1/v_bookings_hoy
```

### Consultar Todos los Bookings Activos
```bash
GET /rest/v1/v_bookings_activos
```

## Bookings Actuales (Marzo 2026)

| Lead | Fecha | Hora | Estado |
|------|-------|------|--------|
| Nicole Pavlou | 17/03 | 14:00 | programado |
| B.K | 20/03 | 14:00 | programado |
| Wasiu Adeshina | 23/03 | 11:00 | programado |

## Consideraciones de Seguridad (RLS)
- Service Role tiene acceso completo a bookings
- Cada agente puede ver solo sus bookings
- Accesso vía email no implementado (usar uuid de usuario)

