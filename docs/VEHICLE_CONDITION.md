# Daños, caída y respuesta de contacto

## Comportamiento implementado

Los impactos del motor físico cambian el comportamiento del vehículo. El jugador y los rivales utilizan el mismo componente `vehicle_condition.gd`; la IA puede consultar `can_drive()` y `crashed` sin generar una copia de telemetría en cada paso.

| Estado | Efecto durante la conducción |
| --- | --- |
| Motor dañado | Reduce el par disponible y altera la regularidad del sonido. Con salud igual o inferior al 10 % deja de propulsar. |
| Dirección dañada | Reduce el ángulo máximo efectivo y puede introducir un pequeño desvío según el lado del impacto. |
| Aerodinámica dañada | Reduce la carga descendente y aumenta la resistencia. Se combina con el rebufo y el aire sucio existentes. |
| Moto caída | Desactiva equilibrio y propulsión. Un impulso inicial de balanceo, la gravedad y las colisiones hacen caer el cuerpo. |
| Reparación explícita | `reset_at()` recoloca, elimina daños y restaura el equilibrio. La sesión gestiona la penalización de recuperación. |

No se recupera una moto caída por mantener pulsado el acelerador. Los rivales sin capacidad de conducir pasan al estado de abandono que administra la carrera.

## Modelo de daño

El componente suma la magnitud de los impulsos de contacto comunicados por `PhysicsDirectBodyState3D` y la divide entre la masa. Ese cociente se usa como una medida de severidad equivalente en m/s; no reconstruye la velocidad exacta de un accidente. La posición del contacto más fuerte determina el lado del daño de dirección. La API utilizada es [get_contact_impulse en Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_physicsdirectbodystate3d.html#class-physicsdirectbodystate3d-method-get-contact-impulse).

Los contactos inferiores a 1,6 m/s equivalentes no disparan un impacto. Los daños empiezan por encima de 3 m/s y crecen con una curva de potencia 1,5. Un intervalo de 0,16 s impide contabilizar como múltiples golpes todos los pasos del mismo contacto. Tras recolocar hay 0,75 s de margen para que se asiente la suspensión. Estos umbrales son ajustes del juego.

La caída de moto se activa por un impulso equivalente de al menos 8,5 m/s, por una inclinación física incompatible con mantenerse sobre las ruedas durante 0,25 s, o por pérdida intensa de agarre durante 0,9 s a más de 54 km/h y más de 37° de inclinación. Se elimina entonces la compensación visual que antes podía mantener erguida la representación del piloto mientras el cuerpo rodaba.

`damage_sensitivity` permite ajustar la severidad de daños por perfil, entre 0,1 y 3; el valor común es 1. No cambia los umbrales de caída. Las dimensiones de colisión, masa e inercia siguen procediendo del perfil y del cuerpo común.

## Efectos de neumáticos y carrocería

Los contactos de suspensión comunican carga, superficie, posición, normal, deslizamiento y bloqueo. Las marcas de goma se dibujan en asfalto y hormigón cuando existe carga y deslizamiento suficiente. Usan un conjunto fijo de 512 segmentos por vehículo, se ajustan a la normal del suelo y se atenúan durante los últimos 8 s de sus 35 s de duración máxima. Al perder contacto o recolocar se corta la línea para que no atraviese el escenario.

Los emisores de partículas son pequeños conjuntos `CPUParticles3D`, compatibles con el renderizador Compatibility. Generan polvo sobre superficies sueltas, humo de neumático al deslizar, salpicaduras sobre pavimento húmedo, chispas en el punto de impacto y humo de avería si la salud del motor baja del 62 %. No generan colisiones adicionales. `engine_smoke_offset_m` configura el punto visual de humo en los ejes locales del chasis; `-Z` es delante y `+Z` detrás. Estos desplazamientos son ajustes visuales, no medidas de una avería real.

El audio sintetiza impulsos de motor, rodadura, deslizamiento, golpes y rozamiento. Lee `engine_cylinders`, el campo que usan los perfiles: dos cilindros en Yamaha, seis en Porsche y doce en ambos monoplazas. La versión anterior consultaba `cylinders` y caía en el valor común de seis. No se incluyen grabaciones específicas de esos motores.

## Telemetría pública

| Campo | Significado |
| --- | --- |
| `damage` | 0 a 1; pérdida máxima entre las tres áreas. |
| `engine_health`, `steering_health`, `aero_health` | 1 sano; 0 totalmente dañado. |
| `crashed`, `can_drive` | Caída y capacidad de propulsión actuales. |
| `impact_serial` | Contador de eventos; cambia una vez por impacto detectado. |
| `impact_strength`, `impact_delta_v`, `impact_position` | Intensidad visual decreciente, severidad equivalente y punto global. |
| `scrape_strength` | Intensidad actual de rozamiento del cuerpo. |
| `repair_serial` | Identifica una reparación sin generar un impacto artificial. |

## Pruebas ejecutadas con Godot 4.6.3

```bash
godot --headless --path . --fixed-fps 120 --script tests/vehicle_condition_checks.gd
godot --headless --path . --fixed-fps 120 --script tests/collision_checks.gd
godot --headless --path . --fixed-fps 120 --script tests/physics_checks.gd
```

`VEHICLE_CONDITION_CHECKS PASS` completó 21 comprobaciones con cero fallos. Usa impactos reales contra una pared, no modifica manualmente la salud para dar por probada la integración.

| Escenario | Resultado observado |
| --- | --- |
| Porsche contra pared a 13 m/s | Impulso equivalente de 12,913 m/s; daño del 26,55 %; motor, dirección y aero afectados; sigue conduciendo. |
| Yamaha contra pared a 24 m/s | Impulso equivalente de 24,979 m/s; daño del 87,64 %; caída y corte de propulsión. |
| Acelerar después de la caída | La moto permanece caída y no se repara automáticamente. |
| Recolocar y acelerar durante 3 s | Porsche 85,96 km/h; Yamaha 84,55 km/h; daños eliminados y sin impacto ficticio. |

También aprobaron las regresiones `COLLISION_CHECKS PASS` y `PHYSICS CHECKS: PASS`: dos impactos contra defensa a 198 km/h, cuatro parejas de choque entre tipos a 144 km/h, obstáculos sólidos, suspensión, aceleración, frenada, dirección y contacto en pendiente/peralte.

La prueba visual `tools/contact_feedback_probe.gd`, ejecutada en una ventana nativa con Compatibility, produjo capturas de bloqueo trasero, impacto y caída. Mostró goma en el suelo, humo del neumático y de avería, y el cuerpo de la Yamaha tumbado; su eje vertical terminó con producto escalar 0,0946 respecto a la vertical del mundo. Las capturas se guardan en `user://qa_contacts/`.

`AUDIO_CONTACT_PROBE PASS` aprobó cinco comprobaciones adicionales del audio con `tools/audio_contact_probe.gd`. Capturó PCM del bus mezclado de Godot mientras la Yamaha estaba al ralentí y después de un choque físico: el pico pasó de 0,0259 a 0,1889, sin silencio ni saturación; el componente consumió el mismo evento de impacto que la física. El controlador Dummy permite comprobar la mezcla en un entorno sin altavoces, pero esta prueba no es una evaluación de escucha. Se reproduce desde una sesión gráfica, sin `--headless`:

```bash
godot --path . --rendering-method gl_compatibility --audio-driver Dummy --max-fps 120 --script tools/audio_contact_probe.gd
```

## Límites

La distribución del daño es una mecánica de conducción ajustable, no una simulación estructural certificada. No deforma la malla, no desprende piezas, no separa al piloto ni simula un ragdoll. Los neumáticos no tienen temperatura ni desgaste acumulado; su indicador de bloqueo y patinaje es una aproximación basada en fuerzas y velocidad de contacto. Las pruebas descritas validan esos escenarios concretos.

## Módulos

- `scripts/physics/vehicle_condition.gd`: estado, impacto, caída y reparación.
- `scripts/physics/vehicle_forces.gd`: transmisión de daños a fuerzas de contacto y aero.
- `scripts/vehicles/vehicle_feedback.gd`: coordinación visual de contactos.
- `scripts/vehicles/tyre_trails.gd`: marcas persistentes con capacidad limitada.
- `scripts/vehicles/vehicle_particles.gd`: emisores y materiales compartidos.
- `scripts/audio/engine_audio.gd`: síntesis de motor, neumáticos y carrocería.
