# SCORING.md — SCL: Sistema de Calificación de Leads
## RentInLondon PRO

## Principio Fundamental

El **SCL (Sistema de Calificación de Leads)** evalúa leads en una escala de **0 a 10 puntos**
usando 5 factores objetivos calculados automáticamente por triggers en Supabase.

**Canal principal de calificación**: WhatsApp Business (WAB).
Todos los canales (redes sociales y marketplaces) derivan los leads al WAB —
la calificación SCL ocurre exclusivamente en ese canal.

**Cumplimiento**: UK Equality Act 2010. Ningún atributo personal influye en el scoring.

**Leads DSS/UC**: No son penalizados en el SCL.
Son gestionados con el flag `es_dss` que filtra propiedades
donde el landlord acepta esta modalidad de pago. Si el lead cumple los
requisitos del landlord (`dss_requisitos_cumplidos = TRUE`),
accede al pool completo de propiedades.

---

## Fórmula SCL

```
scl_score = F1_urgencia + F2_velocidad_wab + F3_presupuesto + F4_completitud + F5_engagement_wab
```

Escala total: **0 – 10 puntos**
Implementado como trigger SQL (`trg_leads_scl_score`) en la tabla `leads`.

---

## Factores de Calificación

### F1: Urgencia — Fecha de Mudanza (0–3 pts)

| Días hasta mudanza | Puntos | Razonamiento |
|--------------------|--------|--------------|
| ≤ 7 días           | +3     | Urgencia extrema — necesita propiedad esta semana |
| 8–14 días          | +2     | Urgencia alta — necesita propiedad en 2 semanas |
| 15–30 días         | +1     | Urgencia media — tiene un mes |
| > 30 días o NULL   | 0      | Sin urgencia inmediata |

### F2: Velocidad de Respuesta en WAB (0–2 pts)

| Tiempo de respuesta   | Puntos | Razonamiento |
|-----------------------|--------|--------------|
| ≤ 10 minutos          | +2     | Lead muy activo — está al teléfono ahora |
| 11–60 minutos         | +1     | Lead activo — respondió pronto |
| > 60 minutos o NULL   | 0      | Respuesta lenta o sin dato |

### F3: Ajuste de Presupuesto al Mercado (0–2 pts)

| budget_fit  | Puntos | Significado |
|-------------|--------|-------------|
| `good`      | +2     | Presupuesto adecuado para la zona y tipo |
| `maybe`     | +1     | Presupuesto ajustado — opciones limitadas |
| `poor`      | 0      | Presupuesto bajo para la zona |
| `unknown`   | 0      | Sin datos suficientes para calcular |

### F4: Completitud de Datos (0–2 pts)

| data_completeness      | Puntos | Campos completados |
|------------------------|--------|--------------------|
| ≥ 0.85 (6–7 campos)    | +2     | Perfil casi completo |
| ≥ 0.57 (4–5 campos)    | +1     | Perfil mayormente completo |
| < 0.57 (< 4 campos)    | 0      | Perfil incompleto |

Los 7 campos evaluados: `nombre`, `telefono`, `zona_preferida`, `presupuesto_max`, `tipo_propiedad`, `fecha_mudanza`, `duracion_contrato_meses`.

### F5: Engagement en WhatsApp Business (0–1 pt)

| wab_engagement_count | Puntos | Significado |
|----------------------|--------|-------------|
| ≥ 3 mensajes         | +1     | Lead comprometido con la conversación |
| < 3                  | 0      | Conversación inicial |

---

## Clasificación de Temperatura

| scl_score | Temperatura | Acción del Agente |
|-----------|-------------|-------------------|
| 7–10      | 🔴 HOT      | Proponer viewing inmediato — **mínimo para cita en oficina** |
| 4–6       | 🟡 WARM     | Nurturing activo, completar datos faltantes |
| 0–3       | 🔵 COLD     | Script-runner reactivación / seguimiento semanal |

> **Mínimo para enviar a cita en oficina: scl_score ≥ 7 (HOT)**

---

## Canal Principal: WhatsApp Business (WAB)

Todos los canales de captación derivan al WAB:

| Canal de captación | Agente inicial | Canal de calificación |
|--------------------|---------------|----------------------|
| WhatsApp orgánico  | Ivy           | WAB directo |
| Facebook/Instagram Ads | Rose      | WAB |
| Gumtree / Rightmove / Zoopla | Salo | WAB |
| Internacional      | Jeanette      | WAB + videollamada |

La calificación SCL ocurre **exclusivamente en WhatsApp Business**.

---

## Manejo de Leads DSS/UC

### Principio
Los leads DSS/UC son una oportunidad de negocio válida
cuando se hace el matching correcto con landlords que aceptan esta modalidad.
**No son leads de menor calidad — tienen un filtro de matching diferente.**

### Campo `es_dss`
- `TRUE` = lead recibe DSS/UC (housing benefit)
- `FALSE` = lead con ingresos estándar
- **Impacto en scl_score: NINGUNO**
- **Impacto en matching: solo propiedades con `acepta_dss = TRUE`**

### Proceso de verificación de requisitos
Si el lead cumple los requisitos del landlord:
- Garantor verificado con ingresos comprobables, O
- Meses de renta adelantada (según exija el landlord), O
- Carta oficial del organismo de vivienda, O
- Carta del empleador (si cambió situación laboral)

→ `dss_requisitos_cumplidos = TRUE`
→ El lead accede al pool completo de propiedades
→ El scl_score se recalcula con los nuevos datos disponibles

**Agente responsable de verificación**: Jeanette (antes del cierre).
**Agentes que registran el flag**: Ivy / Rose / Salo (durante el intake en WAB).

---

## Matriz de Priorización SCL

| scl_score | es_dss | dss_req_cumplidos | Prioridad | Acción |
|-----------|---------------------|------------------------|-----------|--------|
| 7–10 | FALSE | N/A | 🔴 MÁXIMA | Viewing inmediato — pool completo |
| 7–10 | TRUE | TRUE | 🔴 MÁXIMA | Viewing inmediato — pool completo |
| 7–10 | TRUE | FALSE | 🟠 ALTA | Verificar requisitos + matching propiedades compatibles |
| 4–6 | cualquiera | cualquiera | 🟡 MEDIA | Nurturing activo |
| 0–3 | cualquiera | cualquiera | 🔵 BAJA | Script-runner reactivación |

---

## Consulta SQL de Priorización

```sql
SELECT
  nombre, zona_preferida, presupuesto_max,
  scl_score, data_completeness, budget_fit,
  es_dss, dss_requisitos_cumplidos,
  CASE
    WHEN scl_score >= 7 AND (es_dss = FALSE OR dss_requisitos_cumplidos = TRUE)
      THEN 'MAXIMA'
    WHEN scl_score >= 7 THEN 'ALTA'
    WHEN scl_score >= 4 THEN 'MEDIA'
    ELSE 'BAJA'
  END AS prioridad,
  asignado_a
FROM v_leads_activos
ORDER BY scl_score DESC, data_completeness DESC, ultima_interaccion ASC;
```

---

## Lo que el SCL NUNCA considera

Para cumplir con la **UK Equality Act 2010**, el sistema explícitamente excluye:

- ❌ Nombre del lead (no inferencia de origen/etnia/género)
- ❌ País de origen o residencia actual
- ❌ Idioma hablado o acento percibido
- ❌ Edad percibida o real
- ❌ Género o identidad de género
- ❌ Estado civil o familiar
- ❌ Religión o creencias
- ❌ Orientación sexual
- ❌ Discapacidad
- ❌ Fuente de ingresos como penalización

**Si estos datos aparecen en conversaciones, se registran en `compliance_flags` pero NO influyen en el scl_score.**
