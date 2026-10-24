# Vegetación, frenos y perfil vertical

## Vegetación de Polonuevo–Baranoa

Se incluye una ventana del raster categórico original **ESA WorldCover 2021
v200**, no una clasificación del color de una imagen WMS. Se consulta el COG
por ventana y se agregan fracciones de cobertura de sus píxeles de 10 m en
celdas de aproximadamente 40 m. La fecha de observación es 2021: no demuestra
el estado actual de una parcela ni la posición individual de un árbol.

- Clase 10: cobertura arbórea; genera posiciones estimadas únicamente dentro
  de las celdas con al menos 25 % de cobertura.
- Clases 50 y 80: edificaciones y agua; una fracción de al menos 25 % excluye
  la celda de la plantación. Los polígonos OSM de agua/edificios también excluyen.
- La consulta OSM del tramo no encontró árboles ni zonas boscosas registradas.
  Se conservan los elementos acuáticos disponibles; no es un inventario completo
  de edificaciones. La ausencia de etiquetas no demuestra ausencia de árboles.
- Árboles OSM individuales conservan su posición; hileras y áreas generan
  posiciones aproximadas. No se introducen coníferas sin `leaf_type=needleleaved`.
- Se respeta una separación de carretera, arcenes y margen de 4 m, el relieve
  generado, pendientes y un corredor de 120 m. No se planta fuera del terreno.
- Máximo 1.400 posiciones por pista. Se distribuye el presupuesto por todo el
  recorrido, no solo por sus primeros kilómetros. No es un censo forestal.

`MappedVegetation` conserva un plan ligero. Genera como máximo un chunk de
160 m cada 50 ms cerca del coche, mediante MultiMesh compartidos y sin sombras
individuales. Libera nodos y MultiMesh lejanos; mantiene las geometrías de los
tipos de árbol para reutilizarlas. El terreno y la carretera siguen teniendo una
construcción inicial síncrona. Los árboles nuevos son decorativos, sin colisión
de troncos por ahora. No se implementó el pincel de edición en esta entrega.

Los datos quedan empaquetados para funcionar sin internet durante la carrera.
La selección de pista identifica la fuente y el año. Para otras rutas se pueden
incorporar sus propios `landcover_path` y `surroundings_path`; no se reutiliza
la cobertura de Polonuevo en otro origen.

Attribution: © ESA WorldCover project 2021 / Contains modified Copernicus
Sentinel data (2021) processed by ESA WorldCover consortium. **CC BY 4.0**.
[Dataset y cita](https://doi.org/10.5281/zenodo.7254221),
[acceso oficial](https://esa-worldcover.org/en/data-access).
Datos vectoriales: © OpenStreetMap contributors, ODbL 1.0.

Regeneración opcional del raster compacto (no hace falta para jugar):

```powershell
uv run --with rasterio python tools/prepare_landcover.py
```

El comando emite JSON por stdout; no sobrescribe archivos del proyecto.

## Frenado específico de cada vehículo

Los ocho perfiles ya contenían fuerzas máximas distintas; se verificó que se
transmiten a la física. Se añadió soporte para capacidades explícitas de cada
eje (`front_brake_force_n` y `rear_brake_force_n`) y respuesta del sistema
(`brake_response_time_s`). Si se especifican ambos ejes, su suma y proporción
reemplazan `brake_force_n` y `front_brake_bias`. La IA y la trazada utilizan la
misma capacidad mecánica. Telemetría: capacidad total, por eje y fuerza solicitada.

Las unidades son **newtons de fuerza de frenado en el suelo**, no potencia de
motor ni fuerza ejercida sobre el pedal. La desaceleración sigue limitada por
neumáticos, carga y superficie. No se han inventado mediciones de fabricante:
los valores existentes son calibraciones de simulación. No hay simulación
térmica/fading de discos ni geometría de pinzas en este cambio.

## Pendientes sin quiebres bruscos

Las alturas DEM interpoladas linealmente producían cambios de pendiente en
cada punto de control. Ahora se usan transiciones verticales cúbicas monótonas
y un filtro local de ruido DEM de 35 m a lo largo del recorrido. Conserva X/Z y
los datos de origen; el perfil generado sí puede apartarse localmente de las
cotas DEM. El filtro limita su corrección a 3 m respecto a la interpolación
cúbica, sin confundir carreteras cercanas ni mezclar pisos de un cruce.
Terreno, IA, malla y colisión comparten las muestras resultantes.

Se activa por defecto solo para cotas estimadas `provider_dem`; rutas medidas
o herramientas que necesitan segmentos 3D exactamente lineales no se alteran.
`smooth_vertical_profile` permite control explícito. No aplana montañas ni
reconstruye baches reales. Los errores DEM grandes todavía necesitan revisión.
En el tramo incluido, el máximo cambio de pendiente entre muestras bajó de
11,18° a 1,13°, sin aumentar sus 3.724 muestras. Es una medición geométrica,
no una validación del confort del coche ni de exactitud topográfica.

## Verificación de escritorio

```powershell
godot_console --headless --path . --script tests/mapped_vegetation_checks.gd
godot_console --headless --path . --fixed-fps 120 --script tests/braking_profile_checks.gd
godot_console --headless --path . --script tests/vertical_profile_checks.gd
godot_console --path . --rendering-method gl_compatibility --script tools/vegetation_preview.gd
godot_console --headless --path . --script tools/road_profile_probe.gd
```

La vista de vegetación construye la pista real y guarda
`user://qa/polonuevo-vegetation.png`, sin modificar preferencias.

Resultados de esta entrega: pasan las pruebas nuevas de vegetación, frenado y
perfil vertical, además de física, fuerzas reales, fidelidad, rutas abiertas,
acabados de carretera, edición de UI y rendimiento. La prueba de vuelta IA de
Yamaha pasa; la del Porsche en Costa Clara falló por salida de pista y daños.
Una comparación con la rampa de freno anterior también reprodujo una salida.
No se considera validado el flujo de vuelta IA del Porsche ni se adjudica su
causa únicamente a los cambios de frenado. `tools/braking_ai_baseline.gd`
permite comparar sin editar perfiles ni preferencias.
