# COMPLIANCE.md — RentInLondon PRO
## UK Equality Act 2010 + GDPR

## UK Equality Act 2010

### Las 9 Características Protegidas

El sistema RentInLondon PRO nunca usa las siguientes características en ninguna decisión de negocio:

| # | Característica Protegida | Ejemplos de lo que NUNCA hacemos |
|---|--------------------------|----------------------------------|
| 1 | **Edad** | No priorizamos leads por edad percibida. No preguntamos la edad. |
| 2 | **Discapacidad** | No discriminamos por necesidades de accesibilidad. No preguntamos sobre discapacidades. |
| 3 | **Reasignación de género** | No discriminamos por identidad de género. No usamos género en scoring. |
| 4 | **Matrimonio y unión civil** | No discriminamos por estado civil. No preguntamos estado civil. |
| 5 | **Embarazo y maternidad** | No discriminamos por embarazo. No preguntamos sobre embarazo. |
| 6 | **Raza** | No discriminamos por raza, color, origen nacional o étnico. |
| 7 | **Religión o creencias** | No discriminamos por fe. No preguntamos sobre religión. |
| 8 | **Sexo** | No discriminamos por sexo. No preguntamos por género. |
| 9 | **Orientación sexual** | No discriminamos por orientación sexual. |

### Principio de Scoring Justo

**El scoring en RentInLondon PRO se basa ÚNICAMENTE en:**

1. **urgency_score (0-5)**: Calculado por:
   - Proximidad de fecha de mudanza (factor objetivo: tiempo)
   - Velocidad de respuesta del lead (factor objetivo: comportamiento)

2. **data_completeness (0.00-1.00)**: Calculado por:
   - Porcentaje de campos obligatorios completados (factor objetivo: información)

3. **budget_fit (good/maybe/poor/unknown)**: Calculado por:
   - Comparación del presupuesto con rangos de mercado en `zone_ranges` (factor objetivo: mercado)

**Ninguno de estos factores tiene relación con ninguna característica protegida.**

### Lo que Hacemos vs. Lo que NO Hacemos

| ✅ PERMITIDO | ❌ PROHIBIDO |
|--------------|-------------|
| Pedir zona preferida | Preguntar por nacionalidad del inquilino |
| Verificar presupuesto | Cobrar más por ser extranjero |
| Right to Rent para TODOS | R2R solo para personas de ciertos países |
| Referir propiedades por precio/zona | Filtrar propiedades por nombre/apellido |
| Listar propiedades "no mascotas" | Anuncios "no familias" o "solo profesionales" |
| Verificar referencias de empleo | Rechazar por país de trabajo anterior |

### Texto Prohibido en Anuncios

Los siguientes términos y frases están PROHIBIDOS en cualquier comunicación del sistema:

```
"No beneficio de vivienda"
"No benefits"
"Working professionals only"
"No families"
"No children"
"No foreigners"
"English speakers only"
"British passport required"
"White tenants preferred"
"[Cualquier grupo protegido] only/preferred/not accepted"
```

Si se detectan estos términos en notas, interacciones o anuncios, se registran automáticamente en `compliance_audit` y se alerta a Alex.

### Registro en compliance_audit

Cada decisión de scoring o cualquier evento de compliance se registra en la tabla `compliance_audit`:

```sql
INSERT INTO compliance_audit (
  lead_id,
  agente,
  evento,
  decision,
  razon,
  datos_excluidos,  -- qué datos NO se usaron en la decisión
  accion_tomada
) VALUES (
  'lead_uuid',
  'ivy',
  'scoring_aplicado',
  'urgency_score_calculado',
  'Basado en fecha_mudanza y response_speed únicamente',
  ARRAY['nombre','telefono','pais_origen','email'],  -- excluidos explícitamente
  'Lead clasificado como HOT por urgencia objetiva'
);
```

---

## GDPR (General Data Protection Regulation)

### Principios Aplicados

| Principio GDPR | Cómo lo aplicamos |
|----------------|-------------------|
| **Licitud, lealtad y transparencia** | Leads informados del uso de sus datos al primer contacto |
| **Limitación de finalidad** | Datos usados solo para gestión de arrendamiento |
| **Minimización de datos** | Solo campos necesarios en la tabla `leads` |
| **Exactitud** | script-runner normaliza datos; leads pueden corregir |
| **Limitación del plazo de conservación** | Datos de leads rechazados/perdidos eliminables después de 12 meses |
| **Integridad y confidencialidad** | RLS, HMAC, cifrado en tránsito (HTTPS) |

### Campos de Datos Personales en leads

| Campo | Categoría GDPR | Propósito | Tiempo de retención |
|-------|---------------|-----------|---------------------|
| nombre | Dato personal | Identificación | Duración relación + 12 meses |
| telefono | Dato personal | Contacto WhatsApp | Duración relación + 12 meses |
| email | Dato personal | Contacto alternativo | Duración relación + 12 meses |
| zona_preferida | No personal | Matching de propiedades | Sin límite |
| presupuesto_max | No personal | Calificación comercial | Sin límite |
| fecha_mudanza | No personal | Scoring de urgencia | Sin límite |

### Derecho al Olvido

Para eliminar datos de un lead (derecho al olvido GDPR):
```sql
-- Anonimizar (recomendado para mantener integridad referencial)
UPDATE leads SET
  nombre = 'GDPR_REMOVED',
  telefono = NULL,
  email = NULL,
  notas = NULL,
  risk_notes = NULL,
  lead_origin_details = '{}'::JSONB
WHERE id = 'lead_uuid';

-- O eliminar completamente (cascade a interactions, viewings)
DELETE FROM leads WHERE id = 'lead_uuid';
```

### Transferencias Internacionales de Datos

- **Supabase**: Datos almacenados en servidores EU (cumple GDPR)
- **Google Sheets**: Transferencia cubierta por Data Processing Addendum de Google
- **Meta/Facebook**: Uso de Webhooks solo para recepción (no enviamos datos a Meta)

---

## Right to Rent (UK Immigration Act 2014)

### Obligación Legal

Es obligación legal de toda agencia inmobiliaria en Inglaterra verificar el derecho a rentar de TODOS los arrendatarios, sin excepción y sin importar su nacionalidad.

**Esta verificación es un requisito legal — NO discriminación.**

### Proceso Estándar para TODOS

1. Solicitar documentos antes de firmar el contrato
2. Verificar la validez de los documentos
3. Guardar copia de los documentos (cifrada)
4. Registrar en `contracts.r2r_verificado` y `contracts.r2r_tipo_doc`
5. Para derechos temporales: registrar `contracts.r2r_expiry_date` y revisar antes del vencimiento

### Documentos Aceptados (Home Office 2024)

**Lista A (derecho permanente):**
- Pasaporte UK o irlandés
- Pasaporte UE con EU Settled Status share code
- Certificado de naturalización UK
- BRP con permiso indefinido

**Lista B (derecho temporal — requiere seguimiento):**
- Pasaporte + visa válida
- BRP con fecha de expiración
- EU Pre-Settled Status share code (verificar regularmente)

### Verificación Remota

Para leads internacionales, Jeanette sigue el proceso remoto del Home Office:
- Video call con documento en tiempo real
- Plataformas certificadas de verificación digital (ej: Yoti, Thirdfort)
- Share codes de UKVI (gov.uk/view-prove-immigration-status)

---

## Contacto de Compliance

Para reportar preocupaciones de compliance:
- **Internamente**: Enviar `/compliance` a Alex por Telegram
- **Externamente**: Equality Advisory and Support Service (EASS): 0808 800 0082
- **GDPR**: Information Commissioner's Office (ICO): 0303 123 1113
