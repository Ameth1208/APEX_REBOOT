# Colisiones de vehículos y obstáculos

## Estado actual

Los vehículos y obstáculos tienen colisiones físicas. Desde v0.3, los impulsos de contacto también afectan a la potencia del motor, la dirección y la aerodinámica. Un choque fuerte puede derribar una moto: se desactiva el equilibrio asistido, se corta la propulsión y la carrocería cae físicamente con el piloto unido. La reparación y recolocación son explícitas. Los contactos producen marcas de neumáticos, humo, polvo, salpicaduras y sonido según la superficie y el deslizamiento.

La configuración, umbrales, límites y pruebas de ese sistema están en [Daños, caída y respuesta de contacto](VEHICLE_CONDITION.md).

## Corrección de geometría de v0.2

La carretera y los vehículos ya utilizaban cuerpos físicos. La comprobación de impactos encontró dos problemas: el volumen de choque de los coches era bastante más corto que su carrocería y las defensas laterales usaban una superficie triangular sin grosor. En las pruebas a 198 km/h, tanto el Porsche como la Yamaha podían atravesar esa defensa.

Cada vehículo utiliza ahora una envolvente convexa basada en `length_m`, `body_width_m` y `body_height_m`. Incluye los voladizos delantero y trasero; distingue la silueta de coche y moto. Se conserva explícitamente el centro de masa anterior y la misma inercia para mantener la puesta a punto. La envolvente sigue siendo una aproximación: no reproduce cada espejo, hueco entre ruedas, alerón o pieza articulada.

Las defensas tienen volúmenes de choque de 1,15 m de altura y 0,20 m de espesor, con solape entre segmentos. Las dos bandas metálicas y sus postes muestran esa barrera. Los pilares de salida/meta y de viaductos, las farolas y los troncos también tienen colisión. El dibujo de hojas, marcas de pintura y agua permanece visual; las copas de los árboles no forman paredes invisibles.

## Configuración física

| Elemento | Capa | Máscara | Forma |
|---|---:|---:|---|
| Coches y motos | 2 | 3 | Envolvente convexa de carrocería. |
| Carretera y terreno | 1 | 2 | Mallas estáticas de la geometría construida. |
| Defensas y pórticos | 1 | 2 | Cajas estáticas. |
| Pilares, farolas y troncos | 1 | 2 | Cilindros estáticos. |

Los vehículos mantienen detección continua de colisiones y simulación a 120 Hz. Los impactos entre vehículos se resuelven mediante el motor físico: transfieren impulso y pueden desplazar o girar las carrocerías. La fricción del cuerpo es 0,35 y el rebote 0,05; los obstáculos usan 0,60 y 0,02. Son parámetros de juego, no mediciones certificadas de materiales.

El cuerpo físico de la moto usa el modelo de equilibrio del juego mientras puede conducir. Después de una caída deja de recibir esa corrección. No hay deformación de carrocería, desprendimiento de piezas ni un piloto con ragdoll independiente.

## Comprobaciones reproducibles

Con el proyecto importado en Godot 4.6.3:

```bash
godot --headless --path . --fixed-fps 120 --script tests/collision_checks.gd
godot --headless --path . --fixed-fps 120 --script tests/physics_checks.gd
godot --headless --path . --fixed-fps 120 --script tests/vehicle_condition_checks.gd
```

La primera prueba reproduce impactos frontales contra una defensa a 198 km/h con Porsche y Yamaha. Comprueba contacto antes de una penetración visible importante, reacción del impacto y ausencia de atravesamiento junto al suelo. También prueba coche/coche, moto/coche, coche/moto y moto/moto a 144 km/h, midiendo separación de contacto y transferencia de velocidad. Una consulta física verifica pórticos, pilares, farolas y troncos.

La prueba de impactos terminó con `COLLISION_CHECKS PASS`; la regresión, con `PHYSICS CHECKS: PASS`. Ambas se repitieron tras integrar daños y caída en v0.3. La regresión comprueba reposo, suspensión, aceleración, frenada, dirección, equilibrio de moto y conducción sobre pendiente/peralte. `VEHICLE_CONDITION_CHECKS PASS` aprobó 21 comprobaciones adicionales de impacto, pérdida de capacidad, caída física y aceleración después de reparar. Los resultados generales están recogidos en [Verificación](VALIDATION.md).

Estos resultados validan esos escenarios; no garantizan todos los impactos posibles a cualquier velocidad. La consulta de obstáculos confirma que sus formas están registradas en el motor físico; no equivale a una batería de choques contra cada árbol o farola del escenario.

## Archivos responsables

- `scripts/physics/vehicle_collision_shape.gd`: envolvente de cada tipo de vehículo.
- `scripts/physics/static_obstacle_collision.gd`: grupos de obstáculos y formas primitivas.
- `scripts/vehicles/vehicle_body.gd`: capas, detección continua, material, centro de masa e inercia.
- `scripts/physics/vehicle_condition.gd`: daños por impulso, estado de caída y reparación.
- `scripts/vehicles/vehicle_feedback.gd`: efectos de contacto compartidos por jugador y rivales.
- `scripts/tracks/track_props.gd`: defensas, pórticos y pilares.
- `scripts/world/track_scenery.gd`: colisión de farolas y troncos, con renderizado agrupado.
