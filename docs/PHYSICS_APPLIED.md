# Física Aplicada y Mejoras — APEX REBOOT

Documento técnico de las mejoras físicas implementadas. Basado en las especificaciones
de Box3D.NET, Vehicle Physics V2 y Dynamic Racing Line.

---

## 1. Modelo de Neumático (Pacejka Magic Formula)

**Archivo:** `scripts/physics/tyre_forces.gd`

### Fórmula implementada

```
Y(x) = D · sin(C · atan(B·x - E·(B·x - atan(B·x))))
```

Donde:
- `D = μ_eff · Fz` — fuerza pico
- `B` — factor de rigidez (pendiente inicial)
- `C` — factor de forma
- `E` — factor de curvatura (comportamiento post-pico)

### Coeficientes por superficie

| Superficie | B (lat) | C (lat) | E (lat) | B (long) | C (long) | μ base |
|-----------|---------|---------|---------|----------|----------|--------|
| Asfalto | 11.0 | 1.45 | 0.97 | 14.0 | 1.55 | 1.35 |
| Hormigón | 10.0 | 1.40 | 0.97 | 13.0 | 1.50 | 1.20 |
| Grava | 6.0 | 1.35 | 0.90 | 7.0 | 1.40 | 0.72 |
| Hierba | 4.5 | 1.30 | 0.85 | 5.0 | 1.35 | 0.52 |
| Arena | 3.5 | 1.25 | 0.80 | 4.0 | 1.28 | 0.48 |
| Tierra | 5.5 | 1.32 | 0.88 | 6.5 | 1.38 | 0.68 |

### Slip combinado (elipse de fricción)

```
(Fx / μ·Fz)^p + (Fy / μ·Fz)^p ≤ 1
```

Con `p = 2` (elipse clásica). Asegura que frenada + dirección comparten el mismo
presupuesto de agarre.

### Por qué se cambió

- **Antes:** modelo lineal `slip_angle × stiffness` + `clamp` → pérdida brusca de agarre
- **Ahora:** curva Pacejka suave con pico en ~7° de slip, decae gradualmente al 80%
- Resultado: giro estable a alta velocidad, sin pérdida repentina de control

---

## 2. Sensibilidad a Carga

**Sección:** Fricción dependiente de Fz

```
μ_eff = μ₀ · [1 - k_L · max(Fz - Fz₀, 0) / Fz₀]
```

- `k_L = 0.07` (7% de reducción por cada exceso de carga nominal)
- `Fz₀ = 3500 N` (carga nominal por rueda)
- **Solo reduce**, nunca aumenta: a carga baja, μ = μ₀

Esto reproduce el fenómeno real: dos neumáticos a 3000N producen más agarre
total que uno a 6000N.

---

## 3. Temperatura de Neumáticos

**Modelo:** ventana óptima con calentamiento por fricción

### Factor de agarre térmico

| Temperatura | Factor | Estado |
|------------|--------|--------|
| < 40°C | 0.82 – 1.00 | Frío (hasta -18%) |
| 40 – 100°C | 1.00 | Óptimo |
| 100 – 140°C | 1.00 – 0.85 | Caliente |
| > 140°C | < 0.85 | Sobrecalentado |

### Dinámica térmica

```
dT/dt = P_friction · 0.0004 - (T - T_ambient) · convection
convection = 0.010 + speed · 0.0004
```

- Calentamiento proporcional a `Fuerza × velocidad de deslizamiento`
- Enfriamiento proporcional a velocidad (más rápido = más refrigeración)
- Tope: 180°C
- Temperatura inicial: 50°C (no arranca frío)

---

## 4. Suspensión

**Archivo:** `scripts/physics/suspension.gd`

### Tipos soportados

| Tipo | Recorrido | Amortiguación | Camber | Caster |
|------|-----------|---------------|--------|--------|
| McPherson | 0.27m | 0.72 | -0.5° | 4.0° |
| Double wishbone | 0.26m | 0.78 | -0.8° | 6.0° |
| Multilink | 0.24m | 0.75 | -0.5° | 5.0° |
| Leaf spring | 0.20m | 0.70 | — | — |
| Torsion beam | 0.18m | 0.72 | -0.3° | — |

### Muelle progresivo

```
F_spring = compression × k × progressive
progressive = 1 + max(ratio - 0.5, 0) × 1.2 × type_factor
```

Se endurece más allá del 50% del recorrido. Double wishbone es más progresivo.

### Amortiguación asimétrica

- **Compresión (bump):** ×1.0
- **Rebote (rebound):** ×1.6 (más suave)
- **Suelo de carga:** 15% del peso estático (nunca llega a 0)

### Bump stop

```
F_bump = max(compression - travel × 0.85, 0) × k × 4.0
```

---

## 5. Transferencia de Peso

**Concepto:** ΔF_z = m · a · h_CG / L

- Longitudinal: acelerar descarga delantero, frenar lo carga
- Lateral: curva descarga rueda interior, carga exterior
- Implementado vía la compresión diferencial de la suspensión (raycast)

---

## 6. Aerodinámica

**Archivo:** `scripts/physics/vehicle_forces.gd`

### Fuerzas

```
q = 0.5 · ρ · v²
F_drag = q · C_d · A
F_downforce = q · C_l · A
```

### Factor por tipo de vehículo

| Tipo | Factor drag |
|------|------------|
| Moto sport | ×0.88 |
| Moto cruiser | ×1.18 |
| Moto dirt | ×1.25 |
| Carro GT | ×0.92 |
| Track weapon | ×0.85 |
| Pickup | ×1.30 |

### Sensibilidad al yaw

- Aéro menos efectiva con el vehículo de lado (`yaw_factor`)
- Drag ×1.15 a 90° de alineación
- Downforce escala con alineación al flujo

---

## 7. Gravedad WGS84

```
γ = g_e · (1 + c₁·sin²φ + c₂·sin⁴φ) / √(1 - m·sin²φ)
g = γ - 3.086×10⁻⁶ · altitude
```

- Varía con latitud (ecuador vs polo: 9.78 vs 9.83 m/s²)
- Corrección por altitud

---

## 8. Dirección

### Carros: Ackermann + velocidad

- `steer = input × max_steer / (1 + speed × falloff)`
- Falloff por categoría: Sedán 0.032, GT 0.040, Track 0.055, Pickup 0.028

### Motos: geometría real + lean

- **Rake/trail** afectan auto-centrado
- **Steering ratio** por tipo: Sport 1.0, Cruiser 0.72, Dirt 0.85, Touring 0.78
- **Lean rate:** Sport 6.5, Dirt 5.0, Touring 4.2, Cruiser 3.8
- **Balance gain:** Sport 42, Dirt 34, Touring 32, Cruiser 28

### Tipos de moto

| Tipo | Max lean | Rake | Trail | Balance |
|------|----------|------|-------|---------|
| Sport | 51° | 24.5° | 0.090m | 42 |
| Cruiser | 32° | 32.0° | 0.140m | 28 |
| Dirt | 40° | 28.0° | 0.115m | 34 |
| Touring | 37° | 30.0° | 0.130m | 32 |

---

## 9. Track Intelligence (Línea Dinámica)

**Archivo:** `scripts/tracks/track_intelligence.gd`

### Principio

La línea NO se precalcula como "esta curva es roja". Se calcula físicamente:

```
BrakeRisk = a_required / a_available
a_required = (v₀² - v_t²) / (2·d)
```

### Perfil de velocidad: 3 pasadas

1. **Curva máxima:** `v = √(a_y_max / κ)` iterado con downforce
2. **Backward braking:** `v_i = √(v_{i+1}² + 2·a_brake·Δs)`
3. **Forward acceleration:** `v_{i+1} = √(v_i² + 2·a_accel·Δs)`

### Colores dinámicos (continuos)

| Risk | Color | Significado |
|------|-------|-------------|
| 0 – 0.35 | Verde | Velocidad correcta |
| 0.35 – 0.75 | Amarillo → Naranja | Preparar frenada |
| 0.75 – 1.0 | Naranja → Rojo | Frenada fuerte |
| > 1.0 | Rojo intenso | Frenada imposible |

### Se adapta a

- Vehículo (potencia, masa, frenos, aero)
- Temperatura y desgaste de neumáticos
- Lluvia / superficie
- Daños
- Viento

---

## 10. Superficies OSM

Detección automática desde OpenStreetMap:

- **Superficie** por `surface=*` tag
- **Barreras** solo si existen `guardrail/wall/fence`
- **Puente** detectado
- **Tipo de vía** → ancho de escapatoria automático
- **Relieve** calculado desde elevación real de la ruta

---

## 11. Terreno con Elevación Real

- Campo de elevación por inversa-peso desde puntos de la carretera
- Terreno = elevación del camino + ruido (no plano)
- Transiciones suaves entre superficies (blend por vértice, radio 18m)
- Vertex colors: R=arena, G=hierba, B=tierra, A=hormigón

---

## 12. Environment Generator

**Archivo:** `scripts/world/environment_generator.gd`

- Grid de celdas 64×64m
- Bioma automático: urban/agricultural/forest/mountain/coastal/desert
- Pesos de material: `W = P_landcover × (1 - M_road)`
- Zonas LOD: A(0-100m), B(100-500m), C(500m+)
- Paletas regionales por bioma
- GeoBrush para consultas por posición

---

## 13. Temperatura de Frenos y Neumáticos (Telemetría)

Disponible en overlay **F7**:

- Carga por rueda (N)
- Slip lateral y velocidad de slide
- Temperatura de gomas (°C)
- Estado: FRÍO / ÓPTIMO / CALIENTE
- ABS / TCS activo
- Fuerzas vectoriales en pantalla

---

## Métricas de Validación

| Test | Resultado |
|------|-----------|
| Physics checks | PASS |
| Geo checks | PASS (108 assertions) |
| Motorcycle camera | PASS (18 assertions) |
| Vehicle condition | PASS |

### Rendimiento del modelo

| Métrica | Valor |
|---------|-------|
| Carro aceleración máxima | 540 km/h |
| Moto aceleración máxima | 558 km/h |
| Giro carro a velocidad | ~9.8m |
| Giro moto a velocidad | ~2.0m |

---

## Archivos clave

```
scripts/physics/tyre_forces.gd        ← Pacejka, temperatura, fricción
scripts/physics/suspension.gd          ← Tipos, progresivo, damping
scripts/physics/vehicle_forces.gd      ← Contacto, aero, temperatura
scripts/physics/motorcycle_dynamics.gd ← Tipos de moto, lean, countersteer
scripts/tracks/track_intelligence.gd   ← Racing line dinámica
scripts/tracks/track_terrain.gd        ← Terreno con elevación OSM
scripts/world/environment_generator.gd ← Biomas, GeoBrush, zonas
scripts/ui/physics_debug_overlay.gd    ← Overlay F7
```
