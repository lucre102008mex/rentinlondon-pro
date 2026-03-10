# Leads UK — Resumen de Mercado

> Datos actualizados desde Supabase. Ver `shared/snapshots/` para datos en tiempo real.

## Distribución por Canal de Origen

| Canal | Leads activos | Tasa conversión | CPL estimado |
|-------|--------------|-----------------|--------------|
| WhatsApp orgánico | — | — | £0 |
| Facebook/Instagram | — | — | £— |
| Gumtree | — | — | £— |
| Rightmove | — | — | £— |
| Zoopla | — | — | £— |
| SpareRoom | — | — | £— |
| Referidos | — | — | £0 |

## Distribución por Zona

| Zona | Leads buscando | Propiedades disponibles | Match rate |
|------|----------------|-------------------------|------------|
| Shoreditch | — | — | — |
| Islington | — | — | — |
| Camden | — | — | — |
| Clapham | — | — | — |
| Hackney | — | — | — |
| Stratford | — | — | — |
| Brixton | — | — | — |
| Canary Wharf | — | — | — |

## Distribución por Budget Fit

| Categoría | Leads | % del total |
|-----------|-------|-------------|
| Good (presupuesto adecuado) | — | — |
| Maybe (presupuesto ajustado) | — | — |
| Poor (presupuesto bajo) | — | — |
| Unknown (sin datos de zona) | — | — |

## Leads HOT (scl_score 7-10)

Consultar en tiempo real:
```sql
SELECT nombre, zona_preferida, presupuesto_max, scl_score, asignado_a
FROM v_leads_activos
WHERE scl_score >= 7
ORDER BY scl_score DESC, ultima_interaccion ASC;
```

## Leads DSS/UC

| Categoría | Leads | Propiedades compatibles |
|-----------|-------|------------------------|
| Requisitos cumplidos | — | — |
| Pendiente verificación | — | — |
| Ingresos estándar | — | — |

Leads pendientes de verificación de requisitos:
```sql
SELECT * FROM v_leads_dss_pendientes;
```

## Notas de Mercado

_Agregar observaciones del mercado londinense actuales_

---
*Generado automáticamente — ver snapshot para datos en vivo*
