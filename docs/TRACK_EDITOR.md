# Editor de pistas

El editor modifica la geometría que se usa para conducir. Cada punto tiene posición X/Y/Z, anchura, peralte y superficie. La carretera se reconstruye como una malla tridimensional cerrada, con cara superior, laterales, parte inferior y colisión. La elevación no es una ilusión visual ni una textura.

## Circuitos incluidos

| Circuito | Longitud aproximada | Elevación mínima / máxima | Uso |
| --- | ---: | ---: | --- |
| Costa Clara | 3.164 km | 1.9 / 20.2 m | Curvas fluidas, rectas rápidas y cambios de rasante. |
| Sierra Alta | 3.678 km | 3.9 / 70.0 m | Circuito elevado con dos cruces a distinta altura y viaductos. |
| Laguna Técnica | 3.614 km | 0.9 / 5.1 m | Enlazadas y frenadas para practicar con motos y coches. |

Las longitudes se calculan sobre la trayectoria tridimensional suavizada. Al editar puntos, cambian la distancia, la pendiente y la curvatura real del circuito.

## Crear y modificar una pista

1. Abre el editor con uno de los circuitos incluidos como punto de partida.
2. Haz clic en un punto del mapa para seleccionarlo. Su número y altura aparecen junto al marcador.
3. Arrástralo para cambiar X/Z. Mantén **Mayús** al arrastrar para ajustar a una cuadrícula de 10 metros.
4. Cambia **Elevación** para subir o bajar ese punto. Los tramos de entrada y salida se interpolan suavemente.
5. Ajusta **Anchura**, **Peralte** y **Superficie del tramo** en el panel derecho.
6. Ajusta el **Espesor de la pista**, la anchura/material de la escapatoria y el material/relieve del paisaje.
7. Pulsa **Aplicar y conducir** para reconstruir el circuito y entrar en él. Usa **Guardar** cuando quieras conservar el diseño para otra sesión.

El color de la línea representa la pendiente local: azul al bajar, verde en tramos suaves y naranja al subir. El panel inferior muestra el perfil, desniveles y pendientes sobre una ventana seleccionable. La altura local se modifica numéricamente; una ruta geográfica muestra también la cota del archivo/proveedor.

### Controles del mapa

| Acción | Control |
| --- | --- |
| Seleccionar y mover un punto | Clic y arrastrar con el botón izquierdo. |
| Añadir un punto | Doble clic; se inserta en el segmento más cercano. |
| Eliminar un punto | Botón del panel o tecla Suprimir cuando el mapa tiene el foco. |
| Ajustar a cuadrícula de 10 m | Mayús mientras arrastras. |
| Acercar o alejar | Rueda del ratón. |
| Desplazar la vista | Arrastrar con el botón central. |
| Ver toda la pista | Centrar. |
| Recuperar cambios | Deshacer / Rehacer, hasta 64 estados. |

Se requieren al menos cuatro puntos en circuitos cerrados o dos en rutas abiertas. El editor permite hasta 512. Las pistas deben medir al menos 120 metros. Antes de aplicar, se comprueba que los cruces entre ejes de carretera dejen una separación vertical mínima de **espesor + 6 metros**. Si dos tramos se cruzan demasiado cerca, el editor pide elevar uno o mover los puntos.

## Superficies y texturas

Están disponibles **asfalto, hormigón, grava, tierra, hierba y arena**. Puedes utilizarlos en tramos de carretera, escapatorias y terreno. Los cuerpos de colisión identifican la superficie para que la física seleccione su comportamiento de neumáticos. Una textura cambia el aspecto; el tipo de superficie es lo que identifica el material físico.

Los materiales predeterminados emplean texturas procedurales. Para utilizar una imagen propia:

1. Selecciona un punto y elige el tipo de superficie que quieres personalizar.
2. Pulsa **Elegir textura de esta superficie…**.
3. Selecciona una imagen PNG, JPG/JPEG o WebP. El juego guarda una copia PNG.
4. Pulsa **Aplicar y conducir**.

La imagen se aplica a todas las apariciones de esa superficie en el circuito, incluidas escapatorias y terreno. Para personalizar, por ejemplo, la hierba del paisaje, selecciona temporalmente hierba en el punto, elige la textura y después devuelve ese tramo a asfalto. Usa imágenes repetibles sin juntas visibles; resoluciones moderadas evitan desperdiciar memoria. Esta versión importa el color de la superficie, no un paquete PBR de mapas de normales/altura/roughness.

## Guardar, cargar y compartir

**Guardar** escribe un JSON con el nombre del circuito dentro de `user://tracks/`. **Cargar** abre esa carpeta. `user://` corresponde al directorio de datos de la aplicación que Godot crea para el usuario del sistema; no necesitas modificar el código ni la carpeta de instalación.

**Exportar** permite elegir una carpeta del equipo. Se genera un JSON y, si hay imágenes propias, una carpeta acompañante con las texturas. Comparte ambos elementos juntos. **Importar** abre ese JSON y resuelve sus rutas de textura relativas a la carpeta del archivo. Después de revisar el circuito, pulsa Aplicar; puedes guardarlo también dentro de la aplicación.

Aplicar y Guardar son acciones distintas: aplicar cambia la sesión en curso; guardar conserva el archivo del circuito. Volver cierra el editor sin aplicar los cambios pendientes.

## Estructura del formato

```json
{
  "version": 2,
  "closed": true,
  "interpolation": "catmull_rom",
  "name": "Mi circuito",
  "thickness": 1.2,
  "runoff_width": 4.0,
  "runoff_surface": "gravel",
  "terrain_surface": "grass",
  "terrain_hills": 8.0,
  "surface_textures": {},
  "points": [
    {"x": 0, "y": 2, "z": 180, "width": 12, "bank": 0, "surface": "asphalt"},
    {"x": 0, "y": 2, "z": -180, "width": 12, "bank": 0, "surface": "asphalt"},
    {"x": 300, "y": 8, "z": -180, "width": 12, "bank": 3, "surface": "asphalt"},
    {"x": 300, "y": 8, "z": 180, "width": 12, "bank": 3, "surface": "asphalt"}
  ]
}
```

Las distancias están en metros y `bank` está en grados. Cada superficie se aplica desde su punto hacia el siguiente. Con `closed: true` se une el último punto con el primero; con `closed: false` quedan salida y llegada separadas. `interpolation: "linear"` conserva las cotas entre puntos; `catmull_rom` suaviza la trayectoria. `surface_textures` relaciona cada superficie con su imagen; se admiten recursos del proyecto, imágenes copiadas a `user://` y rutas relativas al importar un paquete exportado.

## Alcance actual

El editor crea circuitos cerrados o recorridos de salida a llegada, con interpolación Catmull–Rom o lineal. Permite pendientes, cambios de rasante, peraltes y cruces a distinta altura. El paisaje se genera automáticamente y la carretera mantiene su propia geometría; no se aplana para ajustarla a un terreno 2D. Los viaductos tienen estructura visible y la consulta de posición del vehículo usa distancia tridimensional para distinguir pasos elevados.

No es un editor de terreno por pinceles ni un sistema de túneles excavables. El botón **Ruta real · mapa / GPX…** importa trazados geográficos y permite consultar alturas. [Rutas reales](REAL_ROUTES.md) explica el flujo y el análisis. No importa una pista escaneada ni reconstruye la escena real completa de una carretera. La curva suavizada puede alcanzar cotas ligeramente fuera de las alturas de sus puntos de control. Los cambios muy bruscos de altura o anchura pueden crear trazados difíciles de conducir; la comprobación de cruces no sustituye una vuelta de prueba ni garantiza que cualquier diseño sea apto para la IA.

## Archivos para mantenimiento

- `scripts/tracks/track_definition.gd`: esquema y límites de datos.
- `data/tracks/catalog.json`: orden y rutas de los circuitos incluidos.
- `scripts/tracks/track_sampler.gd`: muestreo, tangentes, normales y posición sobre la pista.
- `scripts/tracks/track_road_mesh.gd`: calzada, espesor, bordes y escapatorias.
- `scripts/tracks/track_terrain.gd`: paisaje y transiciones de hierba.
- `scripts/tracks/track_props.gd`: guardarraíles, parrilla, arco de salida y pilares.
- `scripts/tracks/track_materials.gd` y `shaders/terrain.gdshader`: superficies y texturas.
- `scripts/tracks/track_validation.gd`: comprobación de longitud y cruces.
- `scripts/tracks/editor/`: mapa, controles y almacenamiento del editor.
- `scripts/ui/track_editor.gd`: composición y acciones del editor.
- `tests/track_checks.gd`: cierre, elevación, colisión, espesor, cruces, transformación de salida y acciones del editor.
