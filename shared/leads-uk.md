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

## Leads HOT (urgency_score 4-5)

Consultar en tiempo real:
```sql
SELECT nombre, zona_preferida, presupuesto_max, urgency_score, asignado_a
FROM v_leads_activos
WHERE urgency_score >= 4
ORDER BY urgency_score DESC, ultima_interaccion ASC;
```

## Notas de Mercado

_Agregar observaciones del mercado londinense actuales_

---
*Generado automáticamente — ver snapshot para datos en vivo*
