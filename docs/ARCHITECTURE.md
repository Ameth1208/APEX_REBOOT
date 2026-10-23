# Arquitectura y mantenimiento

APEX REBOOT usa Godot 4.6.3, Compatibility, GodotPhysics3D a 120 Hz y GDScript. Modelos importados aportan la representación; perfiles JSON definen vehículos y pistas. La complejidad del modelo visual no determina su física.

## Responsabilidades

| Área | Archivos principales | Responsabilidad |
| --- | --- | --- |
| Aplicación | `scripts/app/main.gd`, `screens.gd`, `settings.gd` | Composición, transiciones, pantallas y preferencias. |
| Catálogos | `scripts/app/catalog.gd`, `data/*/catalog.json` | Descubrir los perfiles ofrecidos por los menús. |
| Carrera | `scripts/race/race_session.gd`, `lap_tracker.gd`, `career_progress.gd` | Participantes, cronometraje, reglas y progreso. |
| Vehículo común | `scripts/vehicles/vehicle_body.gd` | Cuerpo físico, controles y telemetría. |
| Mecánica | `scripts/physics/` | Suspensión, neumáticos, transmisión, moto y estela aerodinámica. |
| Representación | `scripts/vehicles/vehicle_visual.gd` y auxiliares | Normalización del modelo, ruedas, pintura, decoraciones y piloto de moto. |
| IA | `scripts/ai/speed_planner.gd`, `racing_driver.gd` | Plan de velocidad y órdenes de conducción. |
| Pista | `scripts/tracks/` | Curva 3D, malla, espesor, terreno, materiales y validación. |
| Editor | `scripts/ui/track_editor.gd`, `scripts/tracks/editor/` | Interfaz, mapa, operaciones y archivos de circuitos. |
| Geografía | `scripts/geo/`, `scripts/geo/network/`, `scripts/geo/ui/` | GPX/GeoJSON, proyección, perfiles, cartografía y elevación. |
| Compilación reproducible | `Dockerfile`, `compose.yaml`, `tools/docker/` | Herramientas fijadas y exportación Windows/Linux/Web. |
| Vista y sonido | `scripts/camera/`, `scripts/world/`, `scripts/audio/` | Cámaras, captura, paisaje, iluminación y audio de motor. |

`ApexRaceSession` crea vehículos mediante `ApexVehicleFactory`. Jugador e IA controlan el mismo tipo de cuerpo. `ApexAeroWake` actualiza resistencia/carga de todos; cámaras y animaciones no reposicionan sus cuerpos.

`sample_at(distance)` entrega posición, ejes, anchura, peralte y superficie. La proyección 3D distingue pasos elevados. Convenciones: frente −Z, metros, newtons, m/s y peralte del JSON en grados.

## Añadir un vehículo

1. Coloca un modelo GLB autocontenido —o una escena FBX con sus texturas— en una carpeta propia dentro de `assets/vehicles/`. El cargador admite escenas `PackedScene` y mallas `Mesh/ArrayMesh` importadas desde OBJ; los modelos combinados necesitan separar ruedas/materiales para animación y pintura selectiva.
2. Duplica un JSON de categoría próxima en `data/vehicles/`. Cambia `id`, nombre, ruta del modelo, dimensiones, masa y parámetros. Para dos ruedas usa `kind: "motorcycle"`.
3. Ajusta `model_yaw_deg`, grupos de ruedas, materiales de pintura y `cockpit_camera_ground`. Los parámetros mecánicos y visuales son independientes.
4. Define decoraciones en `liveries` y conserva las fuentes/condiciones del modelo.
5. Añade la ruta del JSON a `data/vehicles/catalog.json`. El menú lo recogerá sin una clase nueva por vehículo.
6. Comprueba garaje, ruedas, Original, cámara de piloto y una vuelta física. [VEHICLES.md](VEHICLES.md) detalla cada campo.

Los perfiles sobrescriben valores comunes. Amplía componentes cuando haga falta una dinámica nueva; evita duplicar `vehicle_body.gd`.

## Añadir pistas y materiales

El editor puede guardar diseños en `user://tracks/` e importarlos durante el juego. Para incorporar uno al catálogo del código fuente, guarda su JSON en `data/tracks/` y añade su ruta a `data/tracks/catalog.json`.

`TrackDefinition` normaliza los datos; `TrackSampler` genera posiciones/tangentes; `TrackRoadMesh`, `TrackTerrain` y `TrackProps` construyen la escena. `surface_textures` asigna una imagen a cada superficie. El shader acepta una textura de color; el identificador del collider determina el material físico. Al exportar desde el editor, las imágenes se copian a una carpeta acompañante y el JSON usa rutas relativas.

## Datos persistentes y actualizaciones

| Ruta en `user://` | Contenido |
| --- | --- |
| `settings.cfg` | Preferencias del jugador. |
| `career.json` | Etapas, puntos y resultados del campeonato. |
| `tracks/` | Circuitos guardados y subcarpeta `textures/`. |
| `photos/` | Capturas PNG. |
| `maps/` | Caché de cartografía ya visualizada. |
| `elevations.json` | Caché de consultas de altura. |
| `geo_services.cfg` | Proveedores alternativos opcionales. |

`user://` corresponde a los datos de **APEX REBOOT**: normalmente `%APPDATA%\Godot\app_userdata\APEX REBOOT` en Windows o `$XDG_DATA_HOME/godot/app_userdata/APEX REBOOT` en Linux. Sin XDG definido, Godot usa el directorio de datos habitual. Mover el ejecutable conserva los datos si el nombre de aplicación no cambia.

Las pistas normalizadas declaran `version: 2`. Los archivos de la versión 1 conservan por defecto circuito cerrado y Catmull–Rom; la versión 2 añade `closed`, `interpolation` y metadatos geográficos sin exigirlos a los archivos anteriores. No existe una migración general para formatos futuros. Copia los datos antes de cambiar formatos y añade conversiones y valores predeterminados explícitos. Preferencias y etapas referencian posiciones de catálogo: **añade entradas al final; reordenar/eliminar requiere migrar índices**. Reordenar etapas también afecta a las claves del campeonato.

## Validación y exportación

Abre/importa el proyecto con Godot 4.6.3 antes de ejecutar pruebas. Con `godot` disponible en el PATH:

```bash
godot --headless --path . --script tests/track_checks.gd
godot --headless --path . --script tests/race_rules_checks.gd
godot --headless --path . --fixed-fps 120 --script tests/physics_checks.gd
godot --headless --path . --fixed-fps 120 --script tests/aero_wake_checks.gd
```

Las pruebas de vueltas/tráfico están en [PHYSICS_AND_AI.md](PHYSICS_AND_AI.md). Comprueba también materiales, cámaras e interfaz: headless no verifica apariencia ni FPS.

`export_presets.cfg` define Windows, Linux y Web. Los asistentes de `tools/` descargan y verifican herramientas oficiales; los recursos importados quedan dentro del paquete `.pck`. `README_ES.md` explica ejecución y exportación. El preset Web sigue siendo una ruta opcional que necesita su propia validación en navegador.

## Rutas geográficas

`points` contiene la geometría vigente en metros locales. `raw_route` es un original inmutable para comparar, y `geo` conserva el origen y la procedencia. El historial comparte los originales en lugar de copiarlos completos al arrastrar cada punto. El análisis construido debe usar la misma interpolación que la carretera. `closed=false` limita muestreo/IA al extremo final y activa reglas de etapa. [REAL_ROUTES.md](REAL_ROUTES.md) documenta el contrato y los límites.

## Cambios de organización en 0.3

| Área | Responsabilidad |
| --- | --- |
| `physics/vehicle_condition.gd` | Daño, caída y recuperación mecánica; se usa en todos los vehículos. |
| `physics/vehicle_forces.gd` | Fuerzas comunes de aerodinámica, rodadura y tracción con estado mecánico. |
| `vehicles/vehicle_feedback.gd`, `vehicle_particles.gd`, `tyre_trails.gd` | Efectos de contacto con límites de partículas/segmentos. |
| `ai/traffic_planner.gd`, `physical_recovery.gd` | Maniobras de tráfico y recuperación física sin cambiar la pose. |
| `race/race_classification.gd` | Orden, tiempos y DNF de todos los participantes. |
| `app/control_bindings.gd`, `ui/controls_panel.gd` | Nombres de teclas, conflictos y edición de asignaciones. |
| `app/vehicle_preferences.gd` | Apariencia recordada por índice de vehículo. |
| `camera/camera_motion.gd` | Movimiento exclusivamente visual a partir de aceleración e impactos. |
| `ui/vehicle_status.gd`, `race_results.gd` | Salud, caída y tabla de resultados. |
| `world/environment.gd`, `shaders/motorsport_sky.gdshader` | Cielo/tiempo y calidad de sombras en vivo. |

`settings.cfg` añade diccionarios `key_bindings` y `vehicle_looks`, curvas/zonas muertas, dificultad y preferencias de cámara. Una instalación anterior toma valores iniciales para las claves nuevas. Cambiar la apariencia no modifica recursos originales. Cambiar la dificultad, humedad, agarre o aero vuelve a planificar la IA sin reiniciar su estado de maniobra o DNF.

El daño se calcula a partir del cuerpo físico, no por vértice ni por el número de piezas del OBJ. El motor sigue siendo GDScript/Godot; no se introdujo una extensión Rust sin una medición que justifique el coste adicional de mantenimiento y exportación.
