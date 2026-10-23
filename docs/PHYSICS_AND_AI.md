# Física, motos, rebufo e IA

## Alcance de esta versión

APEX REBOOT aplica fuerzas a cuerpos `RigidBody3D` de Godot 4.6.3 a 120 Hz. El jugador y los rivales usan la misma clase, contactos, neumáticos y aerodinámica. La IA actúa mediante acelerador, freno y dirección; no impone velocidades ni transforma el vehículo para seguir una curva.

Es una simulación orientada a conducción jugable, con datos nominales y parámetros de comportamiento documentados en `data/vehicles`. Los coeficientes de neumáticos, curvas de par, suspensión y estela se ajustaron para estabilidad. No están calibrados con telemetría del fabricante, ensayos de neumáticos, túnel de viento ni CFD. Los tiempos de las pruebas son resultados de este juego y no representan tiempos reales de esos vehículos.

## Componentes y unidades

| Archivo | Responsabilidad |
| --- | --- |
| `scripts/vehicles/vehicle_body.gd` | Cuerpo común, controles, colisiones, coordinación y telemetría. |
| `scripts/physics/suspension.gd` | Cuatro contactos en coches; dos en motos; muelles y amortiguadores. |
| `scripts/physics/tyre_forces.gd` | Fuerzas longitudinales/laterales, círculo de fricción, superficies, ABS y TCS. |
| `scripts/physics/powertrain.gd` | Par, límite de potencia, marchas, relación final y freno motor. |
| `scripts/physics/vehicle_forces.gd` | Aplicación de contacto y aerodinámica con el estado mecánico del vehículo. |
| `scripts/physics/vehicle_condition.gd` | Daños por impulso, pérdida de capacidad, caída de moto y reparación explícita. |
| `scripts/physics/motorcycle_dynamics.gd` | Piloto virtual, respuesta del manillar y demanda de inclinación. |
| `scripts/physics/aero_wake.gd` | Estela tridimensional, rebufo y pérdida de carga en aire sucio. |
| `scripts/ai/speed_planner.gd` | Velocidad prevista según agarre, peralte, rasantes y capacidad mecánica de frenada. |
| `scripts/ai/racing_driver.gd` | Seguimiento, corrección por giro real y pedales comunes al jugador. |
| `scripts/ai/traffic_planner.gd` | Distancia de seguridad, espacio lateral, adelantamiento y regreso al carril. |
| `scripts/ai/physical_recovery.gd` | Frenada, marcha atrás, realineación y retirada cuando no se puede recuperar. |
| `scripts/race/race_classification.gd` | Orden de llegada, progreso de quienes siguen en pista y abandonos explícitos. |

Las distancias se expresan en metros; masa en kg; fuerza en N; par en Nm; velocidad interna en m/s; ángulos internos en radianes. La interfaz muestra km/h y grados. El frente local del vehículo es `-Z`; un valor positivo de dirección gira a la derecha.

Cada vehículo se configura con un perfil JSON. Agregar otro modelo requiere sus dimensiones, datos mecánicos y grupos visuales; no requiere copiar todo el controlador. Los valores específicos sobrescriben los valores comunes de los componentes.

## Contactos y transmisión

Cada rueda consulta la geometría física bajo el chasis. La compresión y velocidad del contacto producen una fuerza de muelle y amortiguador: `F = k · compresión − c · velocidad_normal`, limitada a una fuerza no negativa. La longitud natural incluye la compresión estática; `ride_height_m` es la altura prevista en reposo. La distribución del peso determina la posición longitudinal de los ejes y su rigidez.

La gravedad, pendientes, peraltes, saltos y transferencias de carga afectan al cuerpo. La capa de colisión 1 contiene carretera/terreno; los vehículos usan la capa 2 y colisionan también entre sí. La carcasa tiene una colisión sencilla independiente de la densidad del modelo artístico.

El motor produce un par dependiente de las rpm. Cuando existe `engine_power_kw`, limita el par mediante `T ≤ potencia / velocidad_angular`. El par atraviesa la marcha, relación final y eficiencia antes de convertirse en fuerza sobre las ruedas motrices. Hay marcha atrás, punto muerto, cambios manuales/automáticos y freno motor. Las relaciones de transmisión y el sesgo delantero de frenada pertenecen al perfil.

## Neumáticos, terreno y asistencias

La fuerza lateral se opone al ángulo de deslizamiento. La fuerza longitudinal incluye tracción, frenada y resistencia a la rodadura. La magnitud combinada no supera `μ · carga_normal`. La rueda descargada pierde capacidad de transmitir fuerza.

Estos son los coeficientes base del juego antes del multiplicador de cada vehículo:

| Superficie | μ seco | Pérdida de μ con humedad 1 |
| --- | ---: | ---: |
| Asfalto | 1,22 | 36 % |
| Hormigón | 1,10 | 35 % |
| Grava | 0,64 | 16 % |
| Hierba | 0,46 | 45 % |
| Arena | 0,42 | 10 % |
| Tierra | 0,63 | 34 % |

`tire_grip_scale` multiplica estos valores. La humedad reduce el coeficiente de forma continua. Cada contacto lee la propiedad `surface` del collider, por lo que salir a una escapatoria cambia la respuesta aunque el vehículo mantenga parte de sus ruedas en asfalto.

| Modo | ABS | TCS | Corrección de estabilidad del coche |
| --- | --- | --- | --- |
| Assisted | Sí | Sí | Sí |
| Sport | Sí | No | No |
| Expert | No | No | No |

El ABS limita la demanda de frenado antes del bloqueo; el TCS limita una demanda de tracción excesiva. El freno de mano actúa en el eje trasero y permite bloquearlo. La corrección de estabilidad amortigua el giro excesivo; no aumenta el límite lateral de los neumáticos.

El modelo de neumático está simplificado. No incluye temperatura, desgaste, deformación ni una curva Pacejka medida. El indicador de deslizamiento representa ángulo lateral, exceso de demanda de tracción y bloqueo por frenada sin ABS. Sus datos activan marcas y partículas de contacto; no son una medición de giro libre de cada rueda.

## Moto e inclinación

La moto tiene un contacto delantero y otro trasero, tracción trasera y mayor reparto delantero de frenada. A baja velocidad, la entrada dirige el manillar. A velocidad elevada, solicita inclinación; la relación usada es `tan(inclinación) = v² · curvatura / g`.

Un piloto virtual corrige el manillar usando el giro medido del cuerpo y mantiene el equilibrio lateral. La inclinación visible se anima alrededor de esa demanda, compensando el pequeño balanceo físico del chasis. El equilibrio se usa en todos los modos de asistencia mientras la moto está en condiciones de conducir, porque el teclado/mando no simula el desplazamiento corporal del conductor. Un impacto fuerte, un vuelco o una pérdida prolongada de agarre lo desactivan: el cuerpo cae y deja de recibir propulsión. El piloto visual permanece unido. La reparación explícita restaura el equilibrio. Los detalles están en [Daños y caída](VEHICLE_CONDITION.md). No se modelan la biomecánica del piloto ni todos los efectos giroscópicos de una moto real.

Para integrar la vista: `body.lean_angle` es la corrección residual que recibe `VehicleVisual.animate`. `body.total_lean_angle` y `telemetry()["lean_angle"]` son la inclinación total respecto a la carretera. `telemetry()["visual_lean_angle"]` conserva la corrección residual. Así, la inclinación no se suma dos veces.

## Aerodinámica, rebufo y aire sucio

La resistencia del aire usa `D = 0,5 · ρ · velocidad² · CdA`. La carga descendente usa `L = 0,5 · ρ · velocidad_frontal² · ClA`, con `ρ = 1,225 kg/m³`. Las fuerzas se aplican al cuerpo; la carga adicional llega a los neumáticos a través de la suspensión.

`ApexAeroWake.update(vehicles, delta)` procesa a todos los participantes. Detecta una estela detrás de un vehículo en movimiento utilizando distancia longitudinal, anchura creciente, altura respecto al líder y alineación de carrocería/velocidad. No concede rebufo a quien está delante, circula en sentido opuesto, queda fuera del cono o se encuentra en un puente separado verticalmente. El efecto aparece y desaparece gradualmente; varias estelas no se multiplican entre sí: prevalece la más fuerte.

El rebufo reduce el coeficiente de resistencia. El aire sucio reduce la carga de los vehículos que generan carga aerodinámica. Ambos afectan exactamente a las mismas fuerzas para jugador y rivales. No se añade potencia ni una aceleración artificial. Una moto sin carga aerodinámica sigue recibiendo reducción de resistencia, pero no pierde una carga que su perfil no tiene.

Los valores máximos predeterminados son 22 % de reducción de resistencia en coches y 28 % en motos; la pérdida máxima de carga es 16 % o 32 % según el área aerodinámica. Son límites de estela completa; la geometría y distancia suelen dar efectos menores. Se pueden sobrescribir con `wake_drag_reduction`, `wake_downforce_loss` y `wake_range_m` en el perfil. La telemetría expone `draft_strength`, `drag_multiplier`, `downforce_multiplier` y `downforce_n`.

## Conducción de la IA

El planificador consulta la misma fricción por superficie y humedad que la física, además de masa, carga aerodinámica, peralte con signo y curvatura vertical de las crestas. La frenada queda limitada por el agarre y por `brake_force_n / mass_kg`: un perfil con frenos débiles empieza a reducir antes. La inclinación de la carretera cambia la carga normal; la gravedad ayuda a frenar cuesta arriba y aumenta la distancia necesaria cuesta abajo. Propaga hacia atrás la velocidad admisible mediante `v_actual² ≤ v_siguiente² + 2 · desaceleración · distancia`. Mantiene margen para corregir la trayectoria. Las motos aplican un margen adicional de velocidad de 0,72 por el modelo de piloto virtual.

Durante la marcha, el controlador mira adelante, calcula la curvatura necesaria y corrige usando el giro real. Reduce el objetivo al acercarse al borde, deslizar lateralmente, perder orientación, sufrir daño en dirección/aerodinámica o perder carga por aire sucio. Los niveles Easy, Normal y Expert cambian el margen del planificador de los rivales. No aumentan la potencia ni el agarre del coche. Cambiar humedad, agarre, aerodinámica o dificultad actualiza el plan durante la sesión sin borrar una maniobra o un abandono.

El tráfico se observa en coordenadas de la carretera. La distancia longitudinal, anchura y longitud de cada vehículo determinan si comparte el corredor del seguidor. La distancia de seguridad combina separación temporal y frenada disponible; el alcance de observación crece con la distancia necesaria para detenerse, también en rectas rápidas con frenos débiles. Antes de salir de la trayectoria nominal, comprueba el ancho útil y ambos lados, incluyendo la aproximación de coches por detrás y su movimiento previsto a 1,2 s. La solicitud lateral cambia gradualmente. Tras superar al rival, espera espacio detrás y regresa al carril nominal; puede ceder si el corredor deja de estar libre. En una maniobra lenta, la dirección anticipa la velocidad solicitada para poder rodear un vehículo detenido antes de quedar parado detrás.

La recuperación usa los controles físicos. Si un vehículo está bloqueado durante varios segundos, frena, comprueba espacio detrás mediante tráfico y rayos físicos, da marcha atrás y vuelve a avanzar orientándose hacia la pista. `recovery_count` cuenta estas maniobras; cada una invalida el intento cronometrado. El controlador nunca recoloca el cuerpo ni le asigna velocidad. Si falta espacio tras varios intentos, el vehículo vuelca, cae fuera del escenario o deja de poder conducir por daño, el rival abandona y queda identificado como DNF. El jugador recibe un aviso con la tecla configurada para recuperar y reparar.

La recolocación explícita del jugador invalida el intento. En etapa abierta conserva únicamente los sectores ya visitados y nunca adelanta su progreso: se puede llegar a meta con resultado inválido o reiniciar para registrar tiempo. Un salto genérico o un sector no visitado siguen sin contar. En circuito conserva la regla de descartar los sectores de la vuelta y volver a completar una vuelta limpia. Las recuperaciones físicas que recorren la carretera sin recolocar el cuerpo conservan los sectores, pero no el tiempo válido de ese intento. Ni un abandono, ni una vuelta inválida, ni la exhibición con piloto automático conceden progreso del campeonato.

La sesión detiene a un rival cuando termina las vueltas solicitadas o la etapa. La clasificación ordena a quienes terminaron por tiempo de llegada, a los demás por progreso y a los retirados como abandonos. La instantánea al terminar el jugador conserva el estado «En pista» de quien aún no cruzó la meta.

Es una IA determinista de conducción con planificación local de tráfico. No es una red entrenada ni una garantía de vuelta óptima, de superar cualquier obstáculo o de completar cualquier geometría creada por el usuario. Carreteras demasiado estrechas, curvas incompatibles con el vehículo, fuertes saltos o accidentes pueden impedir seguir. Los mismos límites físicos se aplican al jugador y a los rivales.

## Validación reproducible

Ejecutar desde la carpeta del proyecto con Godot 4.6.3:

```bash
godot --headless --path . --fixed-fps 120 --script tests/physics_checks.gd
godot --headless --path . --fixed-fps 120 --script tests/aero_wake_checks.gd
godot --headless --path . --fixed-fps 120 --script tests/ai_traffic_checks.gd
godot --headless --path . --fixed-fps 120 --script tests/open_route_ai_checks.gd
godot --headless --path . --fixed-fps 120 --script tests/ai_overtaking_driving_checks.gd
godot --headless --path . --fixed-fps 120 --script tests/ai_recovery_driving_checks.gd
godot --headless --path . --fixed-fps 120 --script tests/traffic_checks.gd
```

`ai_lap_checks.gd` acepta vehículo, pista, ritmo, asistencias y humedad después de `--`:

```bash
godot --headless --path . --fixed-fps 120 --script tests/ai_lap_checks.gd -- yamaha_yzf_2021 sierra_alta 0.84 Sport 0.70
```

### Resultados dirigidos de la versión 0.3

Las 32 comprobaciones de `ai_traffic_checks.gd` aprobaron espacios de adelantamiento libres/ocupados, circulación próxima por detrás, exclusión de un vehículo separado en altura, carreteras estrechas, observación a gran velocidad con frenos débiles, regreso al carril, frenada en pendiente, humedad, fin de etapa, recuperación sin cambio de posición/velocidad, abandono y conservación de estado al replanificar. También comprueban que la clasificación usa el tiempo de llegada y que un abandono no concede puntos.

La etapa física de `open_route_ai_checks.gd` tiene curvas, pendientes y meta abierta. Se ejecutó con los cuatro perfiles, sin vehículos delante. Todos completaron una etapa válida, permanecieron dentro del corredor útil, no necesitaron recuperación y se detuvieron después de cruzar la meta:

| Vehículo | Tiempo simulado | Error lateral máximo | Recuperaciones |
| --- | ---: | ---: | ---: |
| Porsche 992 GT3 RS | 27,508 s | 0,526 m | 0 |
| Yamaha YZF | 33,825 s | 0,476 m | 0 |
| Ferrari 312T | 26,058 s | 0,641 m | 0 |
| Monoplaza Senna 1991 | 23,308 s | 0,712 m | 0 |

`ai_overtaking_driving_checks.gd` coloca un Porsche real detenido delante de otro. El seguidor pasó sin contacto, regresó a su carril en 9,85 s y no necesitó recuperación. Su máximo desplazamiento lateral fue 2,807 m dentro de una carretera de 16 m. Esta prueba detectó y permitió corregir el bloqueo que aparecía al frenar antes de completar el desplazamiento lateral.

`ai_recovery_driving_checks.gd` coloca un Porsche perpendicular a una barrera, con el morro tocándola. El vehículo entró en marcha atrás mediante su transmisión, se realineó y volvió a avanzar. Hizo una maniobra de recuperación y no abandonó. El mayor desplazamiento en un paso físico fue 0,194 m; no hubo recolocación instantánea.

La comprobación adicional de Yamaha sobre Sierra Alta con humedad 0,70, Sport y ritmo 0,84 completó una vuelta en 150,267 s. El error lateral máximo fue 0,798 m y la velocidad máxima 166,663 km/h. No hubo recuperaciones ni caídas y el vehículo permaneció dentro del corredor útil de la carretera.

`traffic_checks.gd` carga la sesión completa de Costa Clara con cuatro Porsche, modelos visuales, cuenta atrás, tres rivales, piloto automático del jugador, colisiones, rebufo, sectores y señal de llegada. Completó la carrera en 101,158 s con una vuelta válida del jugador y cero maniobras de recuperación entre los cuatro vehículos. Los errores laterales máximos fueron 4,743 / 5,104 / 2,433 / 3,024 m. El resultado verifica esa parrilla y circuito concretos.

Estas pruebas verifican comportamiento e integración de la física. Sus tiempos son tiempo simulado a paso fijo; no son una medición de FPS, latencia del mando ni rendimiento de GPU en Windows o Linux.
