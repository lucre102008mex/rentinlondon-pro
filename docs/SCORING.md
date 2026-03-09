# SCORING.md — Algoritmos de Scoring Sin Sesgo
## RentInLondon PRO

## Principio Fundamental

El sistema de scoring de RentInLondon PRO evalúa leads ÚNICAMENTE con criterios objetivos relacionados con la urgencia comercial y la calidad de la información. **Ningún atributo personal o protegido influye en el scoring.**

---

## urgency_score (0-5)

### Fórmula

```
urgency_score = factor_fecha_mudanza + factor_velocidad_respuesta
```

Implementado como trigger SQL en la tabla `leads`.

### Factor 1: Proximidad de Fecha de Mudanza (0-3 puntos)

| Días hasta mudanza | Puntos | Razonamiento |
|---------------------|--------|--------------|
| ≤ 7 días | +3 | Urgencia extrema — necesita propiedad esta semana |
| 8-14 días | +2 | Urgencia alta — necesita propiedad en 2 semanas |
| 15-30 días | +1 | Urgencia media — tiene un mes |
| > 30 días o NULL | 0 | Sin urgencia inmediata |

### Factor 2: Velocidad de Respuesta (0-2 puntos)

| Tiempo de respuesta | Puntos | Razonamiento |
|---------------------|--------|--------------|
| ≤ 10 minutos | +2 | Lead muy activo — está en el teléfono ahora |
| 11-60 minutos | +1 | Lead activo — respondió pronto |
| > 60 minutos o NULL | 0 | Respuesta lenta o sin dato |

### Mapping a Temperatura

| urgency_score | Temperatura | Acción recomendada |
|--------------|-------------|-------------------|
| 4-5 | 🔴 HOT | Contacto inmediato, prioridad máxima |
| 2-3 | 🟡 WARM | Seguimiento en 24h |
| 0-1 | 🔵 COLD | Nurturing, seguimiento semanal |

### Código SQL del Trigger

```sql
CREATE OR REPLACE FUNCTION public.fn_calculate_urgency_score()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  days_until_move INTEGER;
  score           SMALLINT := 0;
BEGIN
  -- Factor 1: Proximidad de fecha de mudanza (0-3 puntos)
  IF NEW.fecha_mudanza IS NOT NULL THEN
    days_until_move := (NEW.fecha_mudanza - CURRENT_DATE);
    IF days_until_move <= 7 THEN
      score := score + 3;
    ELSIF days_until_move <= 14 THEN
      score := score + 2;
    ELSIF days_until_move <= 30 THEN
      score := score + 1;
    END IF;
  END IF;

  -- Factor 2: Velocidad de respuesta (0-2 puntos)
  IF NEW.response_speed_minutes IS NOT NULL THEN
    IF NEW.response_speed_minutes <= 10 THEN
      score := score + 2;
    ELSIF NEW.response_speed_minutes <= 60 THEN
      score := score + 1;
    END IF;
  END IF;

  -- Asegurar rango 0-5
  NEW.urgency_score := LEAST(GREATEST(score, 0), 5);
  RETURN NEW;
END;
$$;
```

---

## data_completeness (0.00 - 1.00)

### Definición

Ratio de campos obligatorios completados vs. total de campos requeridos.

```
data_completeness = campos_completados / 7
```

### Campos Evaluados (7 en total)

| # | Campo | Descripción | Puntos si completo |
|---|-------|-------------|-------------------|
| 1 | `nombre` | No vacío, no NULL | 1/7 |
| 2 | `telefono` | No vacío, no NULL | 1/7 |
| 3 | `zona_preferida` | No vacío, no NULL | 1/7 |
| 4 | `presupuesto_max` | > 0, no NULL | 1/7 |
| 5 | `tipo_propiedad` | No NULL | 1/7 |
| 6 | `fecha_mudanza` | No NULL | 1/7 |
| 7 | `duracion_contrato_meses` | > 0, no NULL | 1/7 |

### Interpretación

| Rango | Interpretación |
|-------|---------------|
| 0.86-1.00 | Perfil completo — listo para matching y viewing |
| 0.57-0.85 | Perfil mayormente completo — continuar recopilando |
| 0.29-0.56 | Perfil incompleto — requiere más intake |
| 0.00-0.28 | Perfil muy incompleto — seguimiento básico |

---

## budget_fit (good / maybe / poor / unknown)

### Definición

Comparación del `presupuesto_max` del lead con los rangos de mercado en la tabla `zone_ranges` para la combinación zona + tipo de propiedad.

### Lógica de Evaluación

```
Si presupuesto_max >= precio_minimo_zona_tipo:
  → budget_fit = 'good'
Si presupuesto_max >= precio_minimo_zona_tipo × 0.90:
  → budget_fit = 'maybe'
Si presupuesto_max >= precio_minimo_zona_tipo × 0.80:
  → budget_fit = 'maybe'
Si presupuesto_max < precio_minimo_zona_tipo × 0.80:
  → budget_fit = 'poor'
Si zona o tipo desconocidos en zone_ranges:
  → budget_fit = 'unknown'
```

### Acciones por budget_fit

| Valor | Acción del Agente |
|-------|-------------------|
| `good` | Presentar propiedades en zona preferida |
| `maybe` | Presentar opciones en zona preferida Y alternativas cercanas más económicas |
| `poor` | Explicar la diferencia de mercado con datos reales, ofrecer zonas alternativas asequibles |
| `unknown` | Solicitar más información de zona/tipo para calcular |

### Ejemplo Práctico

```
Lead: £900/mes para room en Shoreditch (E1)
zone_ranges: room_min = £950, room_max = £1,350

£900 >= £950 × 0.90 = £855 → budget_fit = 'maybe'

Acción de Ivy: "Your budget of £900 is very close to the market rate in Shoreditch (from £950). 
I can show you some rooms there, plus some great options in nearby Bethnal Green 
which starts from £800/month for rooms — often a better value!"
```

---

## Combinación de Scores para Priorización

### Matriz de Priorización

| urgency_score | data_completeness | budget_fit | Prioridad |
|--------------|-------------------|------------|-----------|
| 4-5 | > 0.71 | good/maybe | 🔴 MÁXIMA — contactar en < 1h |
| 4-5 | > 0.71 | poor | 🟠 ALTA — contactar, explicar opciones |
| 4-5 | ≤ 0.71 | cualquiera | 🟠 ALTA — contactar, completar datos |
| 2-3 | > 0.71 | good | 🟡 MEDIA — seguimiento en 24h |
| 2-3 | cualquiera | cualquiera | 🟡 MEDIA — nurturing |
| 0-1 | cualquiera | cualquiera | 🔵 BAJA — nurturing semanal |

### Consulta SQL de Priorización

```sql
SELECT
  nombre,
  zona_preferida,
  presupuesto_max,
  urgency_score,
  data_completeness,
  budget_fit,
  CASE
    WHEN urgency_score >= 4 AND data_completeness > 0.71 AND budget_fit IN ('good','maybe') THEN 'MAXIMA'
    WHEN urgency_score >= 4 THEN 'ALTA'
    WHEN urgency_score >= 2 AND data_completeness > 0.71 AND budget_fit = 'good' THEN 'MEDIA_ALTA'
    WHEN urgency_score >= 2 THEN 'MEDIA'
    ELSE 'BAJA'
  END AS prioridad,
  asignado_a
FROM v_leads_activos
ORDER BY
  urgency_score DESC,
  data_completeness DESC,
  ultima_interaccion ASC;
```

---

## Lo que el Scoring NUNCA considera

Para cumplir con la UK Equality Act 2010, el sistema **explícitamente excluye** de cualquier cálculo:

- ❌ Nombre del lead (no inferencia de origen/etnia/género)
- ❌ País de origen o residencia actual
- ❌ Idioma hablado
- ❌ Acento percibido (no aplica en texto, pero en llamadas: tampoco)
- ❌ Edad percibida o real
- ❌ Género o identidad de género
- ❌ Estado civil o familiar
- ❌ Religión o creencias percibidas
- ❌ Cualquier otro atributo de la EA2010

**Si estos datos aparecen en conversaciones, se registran en `compliance_flags` pero NO se usan en scoring.**
