# Leads Internacionales — Flag y Estado

> Leads con `es_internacional = TRUE` en Supabase. Todos asignados a Jeanette.

## Estado Actual

| Nombre | País de origen | Estado | Documentos R2R | Viewing programado | Contrato |
|--------|---------------|--------|----------------|-------------------|---------|
| — | — | — | — | — | — |

## Por País de Origen

| País | Leads activos | En proceso contrato | R2R verificado |
|------|--------------|--------------------|--------------:|
| España | — | — | — |
| México | — | — | — |
| India | — | — | — |
| Italia | — | — | — |
| Portugal | — | — | — |
| Brasil | — | — | — |
| Nigeria | — | — | — |
| China | — | — | — |
| Otros | — | — | — |

## Checklist de Right to Rent por Lead Internacional

Para cada lead internacional en proceso, Jeanette verifica:

### Ciudadanos UK/Irlanda
- [ ] Pasaporte UK o irlandés válido
- [ ] **O** Certificado de nacimiento UK + foto ID oficial

### Ciudadanos EU (Post-Brexit)
- [ ] Share code de EU Settlement Scheme (settled o pre-settled)
  - Verificar en: https://www.gov.uk/view-prove-immigration-status
- [ ] Pasaporte UE o ID nacional

### Otros Países
- [ ] Pasaporte vigente
- [ ] Visa válida o BRP (Biometric Residence Permit)
- [ ] **O** Share code de permiso de residencia

## Proceso de Video Tour

Jeanette programa video tours para leads internacionales:
1. WhatsApp video call (preferido)
2. Zoom / Google Meet (alternativa)
3. Tour pregrabado en 360° si el lead no puede en horario UK

## Zonas Más Buscadas por Leads Internacionales

Consultar en Supabase:
```sql
SELECT zona_preferida, COUNT(*) as total, 
       AVG(presupuesto_max) as avg_budget
FROM leads 
WHERE es_internacional = TRUE 
  AND status NOT IN ('rechazado','perdido')
GROUP BY zona_preferida
ORDER BY total DESC;
```

---
*Para datos en tiempo real, ver shared/snapshots/ o consultar v_leads_activos con filtro es_internacional=true*
