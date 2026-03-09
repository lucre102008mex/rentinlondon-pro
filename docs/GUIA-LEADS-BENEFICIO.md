# GUIA-LEADS-BENEFICIO.md — Guía Operativa: Leads con Beneficio de Vivienda
## RentInLondon PRO

> **Cumplimiento**: UK Equality Act 2010.
> Los leads con beneficio de vivienda reciben el mismo proceso de calificación SCL que cualquier otro lead.
> El beneficio de vivienda es un **flag de matching**, no un criterio de puntuación.

---

## 1. ¿Qué es el Beneficio de Vivienda?

El **beneficio de vivienda** (housing benefit) es una ayuda gubernamental del Reino Unido que cubre total o parcialmente el coste del alquiler de personas con bajos ingresos o en determinadas situaciones de necesidad.

En el contexto londinense:
- Es gestionado a través del Local Housing Allowance (LHA), calculado por zona postal
- El importe varía según la zona, el tamaño del hogar y la composición familiar
- Muchos landlords aceptan esta modalidad, especialmente en zonas con alta demanda de alquiler asequible
- Algunos landlords añaden requisitos adicionales para mitigar su riesgo (garantor, meses adelantados, etc.)

**Los leads con beneficio de vivienda son una oportunidad de negocio válida y frecuente en el mercado londinense.**

---

## 2. Por Qué Son Oportunidades de Negocio Válidas

- **Volumen**: representan una parte significativa de la demanda de alquiler en Londres
- **Estabilidad**: los pagos del organismo de vivienda suelen ser puntuales y predecibles
- **Fidelidad**: estos leads tienden a quedarse más tiempo en la propiedad
- **Pool de landlords**: trabajar con landlords que aceptan esta modalidad amplía nuestra cartera
- **Diferenciación**: muchas agencias los rechazan; nosotros los atendemos correctamente

**La clave es hacer el matching correcto: lead con beneficio → propiedad con `acepta_beneficio_housing = TRUE`.**

---

## 3. Cómo Identificarlo Durante el Intake en WAB

### Pregunta Neutral en el Intake

Durante el proceso de calificación en WhatsApp Business, el agente debe preguntar de forma neutral:

**En inglés:**
```
Are you currently receiving housing benefit? (This helps me match you with the right properties — it doesn't affect your score in any way) 😊
```

**En español:**
```
¿Recibes actualmente algún beneficio de vivienda? (Esto me ayuda a encontrarte las propiedades correctas — no afecta tu puntuación de ninguna manera) 😊
```

### Señales Durante la Conversación

El agente debe registrar el flag si el lead menciona:
- "I'm on housing benefit"
- "I receive LHA" / "Local Housing Allowance"
- "The council pays part of my rent"
- "I'm on benefits" (en contexto de vivienda)
- Equivalentes en español u otros idiomas

### Acción Inmediata

Al confirmar `es_beneficio_housing = TRUE`:

```sql
UPDATE leads SET es_beneficio_housing = TRUE WHERE id = '[lead_id]';
```

El agente busca propiedades compatibles usando `v_match_beneficio` (ver sección 6).
Si no hay propiedades compatibles → escalar a Jeanette.

---

## 4. Requisitos Comunes de Landlords que Aceptan Esta Modalidad

Los landlords que aceptan leads con beneficio de vivienda suelen pedir uno o varios de los siguientes:

| Requisito | Descripción |
|-----------|-------------|
| **Garantor** | Persona con ingresos verificables que co-firma el contrato |
| **Meses adelantados** | 2–6 meses de renta pagados por adelantado (varía por landlord) |
| **Carta oficial** | Carta del organismo de vivienda confirmando el importe y la regularidad del pago |
| **Carta del empleador** | Si el lead cambió recientemente de situación laboral |
| **Historial de alquiler** | Referencias de alquileres previos sin incidencias |

Los requisitos específicos de cada propiedad están en el campo `beneficio_requisitos` de la tabla `properties`.

---

## 5. Proceso de Upgrade: `beneficio_requisitos_cumplidos = TRUE`

Cuando el lead ha completado los requisitos exigidos por el landlord, se marca como verificado. Esto le da acceso al pool completo de propiedades.

### Checklist de Verificación (responsable: Jeanette)

- [ ] Garantor identificado, nombre y relación con el lead
- [ ] Garantor con ingresos verificables (mínimo 30x el alquiler mensual anual)
- [ ] Meses de renta adelantada confirmados y acordados con el landlord
- [ ] Carta oficial del organismo de vivienda recibida y válida
- [ ] Carta del empleador (si el lead cambió situación laboral recientemente)
- [ ] Historial de alquiler previo revisado (referencias positivas)

### Registro del Upgrade

Cuando todos los requisitos están cumplidos:

```sql
UPDATE leads
SET
  beneficio_requisitos_cumplidos = TRUE,
  beneficio_notas = '[Descripción de los requisitos cumplidos y fecha]'
WHERE id = '[lead_id]';
```

**Agente responsable**: Jeanette (antes del cierre del contrato).
**Agentes que inician el proceso**: Ivy / Rose / Salo (durante el intake en WAB).

---

## 6. Consultas SQL para Ver Propiedades Compatibles

### Leads con beneficio pendientes de verificación

```sql
SELECT * FROM v_leads_beneficio_pendientes;
```

Esta vista muestra todos los leads con `es_beneficio_housing = TRUE` y `beneficio_requisitos_cumplidos = FALSE`, ordenados por `scl_score DESC`.

### Matching leads con propiedades compatibles

```sql
SELECT * FROM v_match_beneficio;
```

Esta vista cruza leads con beneficio contra propiedades con `acepta_beneficio_housing = TRUE`, filtrando por zona, tipo de propiedad y presupuesto.

### Propiedades que aceptan esta modalidad de pago

```sql
SELECT id, direccion, zona, tipo, precio_mensual, beneficio_requisitos
FROM properties
WHERE acepta_beneficio_housing = TRUE
  AND estado = 'available'
ORDER BY zona, precio_mensual ASC;
```

### Leads con beneficio HOT (scl_score ≥ 7)

```sql
SELECT nombre, zona_preferida, presupuesto_max, scl_score, beneficio_requisitos_cumplidos, asignado_a
FROM v_leads_activos
WHERE es_beneficio_housing = TRUE
  AND scl_score >= 7
ORDER BY scl_score DESC;
```

---

## 7. Registro en `compliance_audit` — UK Equality Act 2010

Toda decisión relacionada con leads que reciben beneficio de vivienda debe quedar registrada para cumplimiento legal.

### Cuándo Registrar

- Al marcar `es_beneficio_housing = TRUE` (quién lo registró y en qué contexto)
- Si un landlord rechaza un lead por recibir beneficio de vivienda (posible discriminación ilegal)
- Si hay duda sobre si una propiedad está siendo ocultada a leads con beneficio sin justificación objetiva

### Cómo Registrar

```sql
INSERT INTO compliance_audit (
  lead_id, agente, accion, descripcion, created_at
) VALUES (
  '[lead_id]',
  '[nombre_agente]',
  'beneficio_housing_flag',
  '[descripción de la situación]',
  NOW()
);
```

### Discriminación por Fuente de Ingresos

En el Reino Unido, rechazar a un inquilino **únicamente** por recibir beneficio de vivienda puede constituir discriminación indirecta bajo la **UK Equality Act 2010** si afecta desproporcionadamente a grupos protegidos (discapacidad, género, edad).

**Si un landlord rechaza a un lead exclusivamente por recibir beneficio de vivienda:**
1. Registrar inmediatamente en `compliance_audit`
2. Notificar a Alex para revisión
3. Alex alerta al dueño con evidencia y contexto legal

---

## 8. Flujo Completo del Proceso

```
[Lead menciona beneficio de vivienda en WAB]
           ↓
Agente (Ivy/Rose/Salo) registra:
UPDATE leads SET es_beneficio_housing = TRUE
           ↓
Buscar en v_match_beneficio
           ↓
¿Hay propiedades compatibles?
   ↓ SÍ                    ↓ NO
Presentar opciones       Escalar a Jeanette
compatibles              (busca landlords
                          que aceptan)
           ↓
¿El landlord tiene requisitos?
   ↓ SÍ                    ↓ NO
Iniciar proceso          Proceder al
de verificación          viewing directamente
(checklist Jeanette)
           ↓
¿Requisitos cumplidos?
   ↓ SÍ                    ↓ NO
UPDATE leads SET         Continuar nurturing
beneficio_requisitos_    + apoyo para
cumplidos = TRUE         cumplir requisitos
           ↓
Pool completo de
propiedades disponible
           ↓
Proceder al cierre (Jeanette)
```

---

## 9. Glosario

| Término | Significado |
|---------|-------------|
| `es_beneficio_housing` | Flag en BD que indica que el lead recibe beneficio de vivienda |
| `acepta_beneficio_housing` | Flag en BD que indica que el landlord acepta esta modalidad |
| `beneficio_requisitos_cumplidos` | TRUE cuando el lead ha cumplido todos los requisitos del landlord |
| `beneficio_notas` | Notas del agente sobre la situación específica del lead |
| `beneficio_requisitos` | Descripción de los requisitos del landlord en la propiedad |
| LHA | Local Housing Allowance — importe máximo de beneficio por zona |
| `v_match_beneficio` | Vista de matching entre leads y propiedades compatibles |
| `v_leads_beneficio_pendientes` | Vista de leads pendientes de verificación de requisitos |

---

*Guía operativa — RentInLondon PRO | Cumplimiento UK Equality Act 2010*
