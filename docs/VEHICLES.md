# Vehículos: modelos, materiales y perfiles

Los cuatro archivos del usuario están integrados como vehículos seleccionables. Las categorías usan un cuerpo físico común y perfiles JSON separados; la moto activa una dinámica de dos contactos y equilibrio de piloto virtual. Los modelos visuales no determinan automáticamente la masa, la aerodinámica ni el agarre.

## Inventario verificado

| Perfil | Archivo del usuario | Formato real | Triángulos de origen | Mallas | Frente original |
| --- | --- | --- | ---: | ---: | --- |
| `yamaha_yzf_2021` | `yamaha-yzf-2021.zip` | GLB | 371.509 | 100 | −Z |
| `porsche_992_gt3_rs_2024` | `porsche-992-gt3-rs-2024.zip` | GLB | 1.721.938 | 361 | +Z |
| `ferrari_312t_1976` | `ferrari-312t-1976-wwwvecarzcom.zip` | GLB | 74.387 | 23 | +Z |
| `senna_formula_1991` | `f1-ayrton-senna-1991-car.zip` | FBX | 36.876 | 70 | +Z |

Los recuentos GLB proceden de los índices de sus primitivas. El del FBX se verificó en la escena importada por Godot 4.6.3. No se sustituyeron estos archivos por coches geométricos de ejemplo.

**Identificación de la Yamaha.** El ZIP dice YZF 2021; la jerarquía contiene `yzfr7` y el material `r7_engine_test`. El perfil usa una referencia R7, pero esa identificación es una inferencia del archivo. No debe describirse como una R1 o una superbike de 1.000 cc.

**Identificación de la Ferrari.** Se conserva el nombre 312T / 1976 del archivo. El modelo visual lleva la gran toma de aire de la 312T. No se presenta como una 312T2 autenticada.

**Identificación de Senna.** Es un modelo suministrado bajo ese nombre; el perfil físico toma referencias del McLaren Honda MP4/6. La geometría es un modelo de autor, no un escaneado con medidas certificadas.

## Escala y coordenadas

Todos los vehículos terminan con frente −Z, derecha +X, arriba +Y y el punto más bajo de su geometría en `y = 0`. `VehicleVisual` calcula el AABB de las mallas con todas sus transformaciones originales, gira un contenedor externo y escala uniformemente hasta `length_m`. No sobrescribe las transformaciones internas del modelo ni su esqueleto.

| Perfil | `model_yaw_deg` | Largo visual normalizado | Dimensiones visuales aproximadas, ancho × alto × largo |
| --- | ---: | ---: | --- |
| Yamaha | 0 | 2,070 m | 0,823 × 1,197 × 2,070 m |
| Porsche | 180 | 4,572 m | 2,038 × 1,324 × 4,572 m |
| Ferrari | 180 | 4,143 m | 2,029 × 1,272 × 4,143 m |
| Senna | 180 | 4,496 m | 2,184 × 1,233 × 4,496 m |

El ancho visual incluye espejos y salientes. Los modelos del usuario tienen sus propias proporciones, especialmente el FBX de Senna; por eso sus dimensiones visuales no equivalen a una ficha dimensional certificada. Las colisiones usan un chasis sencillo y estable, independiente de la malla decorativa. `ride_height_m` describe la altura del origen del cuerpo físico sobre el suelo; no es la distancia libre bajo el chasis indicada por el fabricante.

## Color original y colores base

`VehicleVisual.set_livery("Original")` y `VehicleVisual.set_paint(color, true)` juntos restauran los materiales capturados al preparar esa instancia. No alteran recursos de otros vehículos. La decoración Original conserva la que traía el modelo; no supone que sea un color oficial de fábrica.

Los colores base actúan únicamente sobre una lista explícita de materiales de carrocería. Neumáticos, cristales, llantas y piezas mecánicas quedan fuera de esa lista.

| Vehículo | Materiales seleccionados para pintura |
| --- | --- |
| Porsche | `Wheel_Paint_Red_35` — a pesar de su nombre, el archivo lo usa para capó, puertas y carrocería |
| Yamaha | `Material.004`, `Material.005`, `vehicle_generic_smallspecmap [SECONDARY]` |
| Ferrari | `Meshpart2Mtl.005`, `R1Mtl` |
| Senna | `BodyworkRed`, `BodyTexture` |

Al cambiar sólo el color base de la decoración Original, se reemplazan las zonas rojas de las texturas de carrocería mediante una máscara cromática. Así permanecen las zonas blancas, negras y muchos detalles. Una máscara por color no separa semánticamente pintura y logotipos: también puede cambiar pequeños píxeles rojos de un patrocinador. Original siempre permite volver a la decoración inicial. Las variantes conservan los mapas de normales y usan un acabado de pintura simplificado; los mapas completos siguen disponibles al restaurar Original.

### Decoraciones propias por vehículo

Cada perfil incluye `liveries`: cuatro entradas con `id`, `name`, `primary`, `secondary`, `accent` y `pattern`. Los identificadores estables son `Original`, `Heritage`, `Endurance` y `Nightline`; sus nombres visibles, colores y patrones cambian por vehículo.

| Vehículo | Heritage | Endurance | Nightline |
| --- | --- | --- | --- |
| Porsche | Dos franjas longitudinales y banda lateral | Bloques diagonales de color | Filetes centrales y laterales |
| Yamaha | Bandas oblicuas de circuito | Flechas y cheurones | Líneas curvas sobre el carenado |
| Ferrari | Banda central clara con bordes verdes | Bandas transversales de época | Líneas en V con tonos dorados |
| Senna | Cuña delantera y franja lateral | Cuadros traseros y franjas | Cintas curvas en cian y rosa |

Son diseños originales creados para el juego, no réplicas certificadas de decoraciones históricas. `paint_shader.gd` genera los gráficos en coordenadas del vehículo normalizado: no dependen de su posición en el circuito ni añaden archivos de textura. Los patrones afectan únicamente a los materiales de carrocería declarados. Retienen detalles oscuros de sus texturas, pero pueden cubrir los colores y logotipos claros; la decoración Original queda disponible sin esa transformación.

`set_livery(id)` conserva la elección de pintura. Con `set_paint(color, true)` la decoración usa su paleta predefinida; con `set_paint(color, false)` el color elegido sustituye su tono primario y mantiene los dos tonos de contraste. Cualquier identificador de decoración desconocido vuelve de forma segura a Original. Añadir otra paleta para un patrón existente sólo requiere editar JSON; un patrón nuevo se añade en el módulo de shader.

### Reparación de materiales de la Yamaha

La inspección de su GLB mostró imágenes blancas utilizadas como albedo de neumáticos, plásticos, llantas, motor y piezas metálicas. Por eso una importación literal producía neumáticos y motor blancos.

`material_repairs` del perfil define correcciones concretas por nombre: caucho oscuro, plásticos oscuros, metales con rugosidad apropiada y transparencia del parabrisas. Se conservan los mapas de normales, la pintura negra original de los carenados, insignias y tablero. Estas correcciones son decisiones visuales de simulación, no una captura de materiales de fábrica. Se aplican antes de memorizar Original. El archivo fuente permanece intacto.

## Animación de ruedas

Los pivotes se calculan en el espacio local ya normalizado. La velocidad gira las ruedas alrededor del eje X; la dirección positiva de los controles gira las delanteras a la derecha. `animate(speed_mps, steering_rad, lean_rad, delta)` recibe el ángulo residual de inclinación de la dinámica de la moto y aplica `rotation.z = -lean_rad`.

| Vehículo | Integración de ruedas |
| --- | --- |
| Porsche | Cuatro grupos originales `WHEEL_LF_519`, `WHEEL_RF_614`, `WHEEL_LR_556`, `WHEEL_RR_642` |
| Yamaha | Dos pares de mallas sin skin: `wheel_lf_child*` y `wheel_lr_child*`; los 96 elementos con skin conservan su esqueleto |
| Ferrari | Las parejas de neumáticos y llantas se separan por triángulos izquierda/derecha en memoria, conservando UV, normales, tangentes y materiales |
| Senna | Cuatro parejas de neumático/llanta identificadas en las superficies FBX; piezas de suspensión y freno permanecen fijas |

`wheel_mesh_splitter.gd` sólo procesa las cuatro mallas indicadas en `split_wheel_meshes` de la Ferrari. La comprobación de anchura impide girar accidentalmente una malla que todavía contenga ambos neumáticos del eje.

`sync_suspension(contacts, delta)` desplaza verticalmente cada pivote a partir de la compresión que calcula la suspensión física. Conserva su posición de reposo y separa los contactos por `index`: delante izquierda/derecha 0/1, detrás izquierda/derecha 2/3; moto delante/detrás 0/1. El lado se deduce de X después de normalizar el modelo, no del nombre del archivo. La compresión estática de 0,10 m en coches y 0,115 m en moto mantiene la posición de origen. Al perder contacto la rueda se extiende; `suspension_travel_m` limita el recorrido total, y un suavizado dependiente del tiempo evita saltos visuales. Este módulo no modifica las fuerzas, colisiones ni parámetros físicos. Anima las ruedas separadas; no deforma brazos de suspensión ni horquillas que estén unidos a la carrocería del modelo.

### Piloto de la moto y cámara

El archivo Yamaha no incluía piloto. `motorcycle_rider.gd` incorpora **Superhero Male FullBody**, un humano articulado de [Quaternius, Universal Base Characters](https://quaternius.com/packs/universalbasecharacters.html), descargado de la edición Standard gratuita bajo CC0 1.0. Son 14.318 triángulos, tres mallas y un esqueleto de 65 huesos, incluidos los dedos. El archivo original mira a +Z; la integración gira 180° y aplica escala 0,98. El modelo es humano y estilizado; no es un escaneado fotorrealista ni un piloto real identificado.

`rider_pose.gd` usa cinemática inversa de dos segmentos para brazos y piernas, conservando sus longitudes. Ancla las muñecas cerca de los puños del manillar y los tobillos junto a las estriberas. Los dedos se flexionan para la postura de agarre. Al aumentar la velocidad, el torso se agacha; al inclinar la moto, la pelvis se desplaza unos centímetros manteniendo esos apoyos. Todo comparte la inclinación de `VehicleVisual`; el piloto visual no añade fuerzas ni altera la masa ya incluida en el perfil físico. Es una animación de conducción calculada, sin simulación de tejidos, articulaciones físicas ni retargeting universal de cualquier esqueleto.

`rider_suit.gd` conserva los buffers fuente y crea una malla de instancia con coordenadas anatómicas en UV2; el shader dibuja un mono, guantes y costuras estables al deformarse. La cara conserva las texturas del autor. El casco de cara completa, su visor transparente y las cubiertas de botas son geometría original. La malla fuente, su skin y las texturas quedan intactas en `assets/rider/quaternius/`; allí están la licencia, sus hashes y los nombres exactos del ZIP. La autoría completa se conserva en `assets/rider/THIRD_PARTY_NOTICES.md`.

`show_rider`, `rider_scale` y `rider_offset` permiten desactivarlo o ajustar su encaje. `rider_model_path` apunta al humano compatible; `rider_procedural: true` activa el personaje geométrico anterior, que también sirve como respaldo si falta el recurso. Los puntos `rider_seat`, `rider_grip` y `rider_ankle` ajustan asiento, puños y tobillos en metros respecto al suelo normalizado; X de puño/tobillo es la distancia positiva que se refleja por lado. Otro personaje requiere adaptar los nombres de huesos y sus máscaras, no basta con cambiar la ruta.

`VehicleVisual.set_cockpit_view(true)` oculta casco, cara, torso y parte superior de los brazos para despejar la cámara de piloto; mantiene manos y antebrazos articulados. La máscara se basa en las coordenadas de reposo, por lo que no cambia al inclinarse. `cockpit_camera_ground` define la posición de cámara respecto al suelo del modelo, independiente de la altura del origen del cuerpo físico.

Prueba dirigida del humano: combinaciones de 0, 25 y 60 m/s con inclinación de −0,6, 0 y +0,6 rad, verificando los cuatro objetivos de muñeca/tobillo; error numérico inferior a 0,01 mm con los puntos configurados. Eso verifica el solver, no una medición de contacto milimétrico contra los polígonos del manillar. Se revisaron renders nativos laterales, frontales, traseros y de cámara de piloto, corrigiendo asiento, dedos, casco, botas y costuras. Los cuatro archivos de vehículos originales no se modificaron para añadir al personaje.

## Qué datos son referencias y qué datos son ajustes

Las cifras nominales verificadas sirven como punto de partida; **los perfiles no son modelos de dinámica validados contra telemetría real**. `simulation_status`, `sources`, `specification_defaults`, `identity_note` y `mass_note` hacen visible esa distinción en los datos.

| Referencia | Masa del vehículo de referencia | Masa usada, con piloto virtual de 75 kg | Potencia nominal configurada |
| --- | ---: | ---: | ---: |
| Porsche GT3 RS | 1.450 kg DIN | 1.525 kg | 386 kW |
| Yamaha R7 como referencia | 188 kg con líquidos | 263 kg | 54 kW |
| Ferrari 312T | 575 kg | 650 kg | 364 kW |
| McLaren Honda MP4/6 como referencia | 505 kg, ficha Honda | 580 kg | 540,6 kW |

Las relaciones de transmisión, curvas de par, fricción, distribución de masas, frenos, rigidez, amortiguación y coeficientes aerodinámicos no identificados como verificados son ajustes de simulación. La moto incluye la reducción primaria en `final_drive`; no usa sólo la relación de piñón y corona. La masa de combustible no varía durante una carrera.

Campos principales:

| Grupo | Campos |
| --- | --- |
| Presentación | `id`, `display_name`, `short_name`, `category`, `category_label`, `description` |
| Modelo | `model_path`, `model_yaw_deg`, `length_m`, `paint_materials`, `liveries`, `wheel_groups` |
| Motor | `engine_power_kw`, `engine_torque_nm`, `idle_rpm`, `max_rpm`, `gear_ratios`, `final_drive`, `drive` |
| Chasis | `mass_kg`, `wheelbase_m`, `track_width_m`, `wheel_radius_m`, `ride_height_m`, `front_weight_fraction` |
| Conducción | `tire_grip_scale`, `brake_force_n`, `front_brake_bias`, `max_steer_deg`, `max_lean_deg` |
| Aerodinámica | `drag_area_m2` y `downforce_area_m2`: área efectiva multiplicada por el coeficiente, en m² |

`tire_grip_scale` es un multiplicador de la fricción del asfalto base. `grip` contiene el coeficiente seco equivalente (`1,22 × tire_grip_scale`) para compatibilidad. La carga aerodinámica se configura por perfil y velocidad; no se calcula mediante CFD a partir de los polígonos.

### Fuentes de especificaciones

- [Yamaha, presentación de la YZF-R7 del 19 de mayo de 2021](https://global.yamaha-motor.com/news/2021/0519/yzf-r7.html): dimensiones, batalla, 188 kg, 67 N·m y reducción secundaria.
- [Yamaha, ficha japonesa publicada en diciembre de 2021](https://global.yamaha-motor.com/jp/news/2021/1216/yzf-r7.html): referencia de 54 kW. La identidad R7 del archivo sigue siendo inferida.
- [Porsche, 911 GT3 RS](https://www.porsche.com/international/models/911/911-gt3-rs/911-gt3-rs/): potencia, masa DIN, 9.000 rpm y siete marchas. [Porsche Finder, ficha 992 I](https://finder.porsche.com/md/en-MD/details/porsche-911-gt3-rs-new-KKZX3M): dimensiones y par.
- [Ferrari, 312 T](https://www.ferrari.com/en-CA/formula1/312-t): 575 kg y 364 kW a 12.200 rpm. Las dimensiones de este perfil se consideran referencia de simulación sin certificación en esta entrega.
- [Honda, McLaren Honda MP4/6 de 1991](https://global.honda/en/F1/machine/1991_McLarenHondaMP46/): dimensiones, 505 kg, seis marchas y 735 PS a 13.500 rpm. 735 PS equivalen aproximadamente a 540,6 kW. [Historia oficial de McLaren](https://www.mclaren.com/racing/heritage/formula-1/cars/1991-formula-1-mclaren-mp4-6/) describe las variaciones del motor durante esa temporada; no existió una única calibración de carrera invariable.

## Añadir o cambiar un vehículo

1. Coloca un GLB autocontenido en una carpeta propia dentro de `assets/vehicles/`. En FBX conserva sus texturas relativas. También se admite OBJ importado por Godot como `Mesh`/`ArrayMesh`: `vehicle_model_loader.gd` crea su `MeshInstance3D` y aplica la misma normalización. Conserva junto al OBJ su MTL y las imágenes relativas.
2. Duplica un perfil de categoría cercana en `data/vehicles/` y cambia `id`, nombres, `model_path` y cifras. Para una moto usa `kind: "motorcycle"`.
3. Define su largo real o de referencia, y `model_yaw_deg` para que mire a −Z. No reexportes sólo para corregir centímetros frente a metros: la normalización lo resuelve.
4. Añade únicamente los nombres de materiales de pintura a `paint_materials`. Si el modelo no tiene geometría separable, deja `wheel_groups` vacío hasta preparar un rig válido.
5. Añade la ruta del JSON a `data/vehicles/catalog.json`. El menú consume este catálogo; no hace falta crear una clase de código por coche.
6. Conserva autoría y condiciones del modelo dentro de su carpeta. Comprueba el vehículo en el garaje y en una vuelta antes de distribuirlo.

OBJ describe geometría estática: no aporta un rig de ruedas, esqueleto ni jerarquía de suspensión. Sus grupos de material pueden convertirse en superficies de una única malla, sin nodos independientes para girar cada rueda. La pintura sólo puede aislar las superficies que tengan materiales diferenciados y nombrados en `paint_materials`; si carrocería y neumáticos comparten el mismo material no deben seleccionarse juntos. Para animar piezas independientes conviene preparar la jerarquía en una escena de Godot o exportar GLB; el importador visual no adivina ruedas a partir de un OBJ combinado.

## Importación, rendimiento y conservación

`python tools/import_assets.py --source-dir RUTA_A_LOS_ZIP` reproduce la copia inicial desde los cuatro ZIP del usuario. El programa sólo escribe los miembros esperados; no ejecuta archivos de los ZIP ni extrae rutas arbitrarias. Los GLB ya incluyen sus texturas. Para el FBX se recrea `downloaded.fbm/` y se cambia la extensión de las copias JPEG de `.jpeg` a `.jpg`, que es la ruta que realmente referencia el FBX.

Cada carpeta incluye `source-audit.json` con origen y SHA-256. Los archivos fuente siguen byte a byte como en los ZIP. Godot genera LOD y mallas de sombra; las instancias usan `lod_bias = 0.6`. No se anuncia una reducción de polígonos del original: el Porsche todavía tiene una fuente de 1,72 millones de triángulos y requiere más recursos que los monoplazas. La primera importación puede tardar varios minutos; un ejecutable exportado utiliza los recursos importados.

Pruebas realizadas: carga de los cuatro modelos en Godot 4.6.3, dimensiones normalizadas, número de pivotes, aplicación de pintura y capturas renderizadas de Original/Azul y las doce decoraciones nuevas. Después de recorrer las tres decoraciones, las capturas de Original restaurado coincidieron píxel a píxel con las de Original inicial en los cuatro vehículos. También se verificaron visualmente la postura del piloto, la vista de casco y la dirección/giro de las ruedas separadas de la Ferrari. Las pruebas de dinámica y de carrera se describen en la documentación general del proyecto.

## Autoría y condiciones de los modelos

Consulta `assets/vehicles/THIRD_PARTY_NOTICES.md`. El Porsche declara **CC BY-NC-SA 4.0**, que incluye condición no comercial. La Ferrari declara **CC BY 4.0**. La Yamaha sólo incluye copyright VTX; el ZIP de Senna no contiene una licencia de uso. El permiso de utilizar y distribuir el código del juego no concede automáticamente derechos sobre esos dos modelos sin licencia identificada ni elimina las condiciones del Porsche.
