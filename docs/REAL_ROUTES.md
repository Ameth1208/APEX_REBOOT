# Rutas reales y análisis de pendientes · versión 0.2

El editor transforma un trazado geográfico en una pista 3D para coches o motos. Conserva las coordenadas de origen, las cotas y su procedencia. La carretera construida utiliza la misma física que los circuitos incluidos.

## Importar un GPX o GeoJSON

1. Abre **F2 → Ruta real · mapa / GPX… → Importar GPX / GeoJSON…**.
2. Selecciona un archivo. Si contiene varias rutas o segmentos, elige uno en el desplegable. No se unen segmentos separados por un salto de GPS.
3. Revisa el recorrido en el mapa. Por defecto se crea una **ruta abierta, de salida a llegada**. Marca Circuito cerrado únicamente cuando quieras conectar sus extremos.
4. Si faltan alturas, pulsa **Obtener cotas y analizar**. Se conservan las alturas existentes; la casilla de sustitución permite recalcular también esas cotas.
5. Pulsa **Crear pista y ver perfil**. Revisa el perfil, las pendientes, la anchura, el peralte y los posibles cruces. Después usa **Aplicar y conducir** y **Guardar**.

Se admiten GPX `trk/trkseg/trkpt` y `rte/rtept`, y GeoJSON `LineString`, `MultiLineString`, `Feature` y `FeatureCollection`. GPX usa `lat`/`lon` y `ele` opcional; GeoJSON usa `[longitud, latitud, altura opcional]`. Se esperan coordenadas WGS84. Un GeoJSON con otro CRS necesita reproyección previa. Los puntos aislados y los polígonos no se convierten en carreteras.

En Windows y Linux se usa el selector de archivos. En web, la importación abre el selector del navegador. El JSON de APEX se importa desde **Importar JSON**, no desde el importador geográfico. En web se puede descargar ese JSON si no lleva un paquete de texturas externas; los paquetes con imágenes se exportan desde la versión nativa.

## Dibujar sobre un mapa

El mapa inicial está centrado en Bogotá. Introduce otra latitud/longitud y pulsa **Ir**, o importa un archivo para centrar la vista en su ruta.

| Acción | Control |
| --- | --- |
| Añadir un punto al final | Clic izquierdo. |
| Quitar el último punto | Clic derecho o Quitar último. |
| Desplazar | Arrastrar con botón central. |
| Acercar/alejar | Rueda. |
| Encuadrar el recorrido | Centrar ruta. |
| Empezar otro trazado | Limpiar ruta. |

Coloca suficientes puntos para seguir las curvas. **Los puntos se unen según el trazado dibujado; no hay un servicio de cálculo de rutas ni ajuste automático a las calles.** Obtener alturas no corrige una trayectoria que corta una curva. La anchura inicial es una elección del usuario, no una medida extraída del mapa.

Los mapas muestran cartografía OpenStreetMap. Solo se solicitan las teselas visibles, con caché de al menos siete días y atribución visible. No se descargan regiones para uso sin conexión. Si el servicio no responde, puedes seguir importando, analizando y conduciendo rutas con cotas ya incluidas.

## De dónde sale la altura

| Fuente | Comportamiento |
| --- | --- |
| GPX/GeoJSON con alturas | Se conservan sus cotas y su trazado original. La exactitud depende del archivo. |
| SRTM a través de Open Topo Data | Modelo con separación nominal de aproximadamente 30 m. Opción predeterminada nativa. |
| Copernicus GLO-90 a través de Open-Meteo | Modelo con separación nominal de 90 m. Opción predeterminada web porque el servicio permite CORS. |
| Plano de prueba | Solo si se marca expresamente. Todas las alturas se ponen a cero y el perfil indica que no hay altimetría real. |
| Ediciones manuales | Se modifica la pista construida; el perfil original sigue conservándose por separado. |

Antes de consultar un proveedor se densifican los segmentos, solicitando normalmente un punto cada 50 m como máximo. El límite es de 512 muestras; si no caben, aumenta la separación conservando los vértices y se registra la separación efectiva. **Muestrear cada 50 m no convierte una fuente de 90 m en una medición de 50 m.**

Las consultas se hacen en lotes de hasta 100 puntos, con pausa entre lotes y caché local. Solo se envían las coordenadas necesarias al proveedor seleccionado. No se envían modelos de vehículos ni otros archivos. No hay búsqueda automática de alturas al conducir. Un error, cancelación o hueco de cobertura conserva el borrador; no se reemplaza silenciosamente por una carretera plana.

SRTM y Copernicus describen una superficie de elevación, no una medición garantizada del pavimento. Revisa puentes, túneles, taludes y cambios recientes. La separación horizontal de la cuadrícula no es su error vertical. Las alturas de distintos archivos/proveedores pueden usar referencias verticales distintas; la versión 0.2 registra una referencia no especificada cuando no puede demostrarla y no hace una transformación de datum vertical.

## Cómo leer el perfil

El panel inferior del editor muestra longitud horizontal, ascenso y descenso acumulados, cotas mínima/máxima y pendientes máximas positivas/negativas. El color del mapa representa pendiente local: azul para bajada, verde para tramos suaves y naranja para subida. El panel de perfil calcula pendientes sobre una ventana de **50, 100 o 250 m**. Por ello un pequeño cambio brusco puede tener un color local intenso y una pendiente media menor en el perfil.

```text
pendiente (%) = 100 × cambio de altura / distancia horizontal recorrida
ángulo (°)    = atan(pendiente / 100) × 180 / pi
```

Subir 10 m en 100 m horizontales equivale a **10 %**, aproximadamente **5,71°**. La distancia horizontal sigue los segmentos de la ruta; no se sustituye por la cuerda entre extremos ni por la distancia 3D. El signo indica subida o bajada en el sentido de marcha. **Peralte** es inclinación transversal; **inclinación de la moto** es el movimiento del vehículo.

Pasa el cursor por el perfil para leer la cota, pendiente, ángulo y ventana efectiva de una muestra. El punto de edición correspondiente se selecciona en el mapa. Seleccionar un punto del mapa también lo marca en el perfil construido. Para rutas más cortas que la ventana, se usa su distancia disponible y se indica ese valor.

**Perfil original** conserva el archivo/trazado de entrada. **Pista construida** analiza los puntos actuales y, si eliges Catmull–Rom, las muestras de la curva que utiliza la carretera. No mezcles ambos cuando hayas editado las cotas o simplificado el trazado. Los huecos de altura dejan tramos sin perfil y totales desconocidos; no se interpretan como cero. El desnivel acumulado suma subidas/bajadas sucesivas, no solo la diferencia entre cota máxima y mínima.

La interpolación lineal predeterminada de las rutas geográficas conserva las cotas entre puntos. Catmull–Rom suaviza, pero puede sobrepasar las alturas de control y modificar pendientes: revisa el perfil construido al activarla.

## Ruta abierta y conducción

En una ruta abierta la carretera termina en la llegada. El muestreo y la IA no saltan al inicio. Las sesiones cronometradas tienen una sola etapa y muestran metros restantes; los rivales planifican la frenada al final. Hay una pequeña zona de frenado posterior, fuera del recorrido medido. El modo Libre permite explorar y recolocar el vehículo.

La ruta pasa por validación de coordenadas, cotas, longitud y cruces antes de reconstruirse. Los saltos verticales necesitan corregirse. La separación entre ejes de vías cruzadas debe superar el espesor más seis metros. Esta validación no garantiza que cualquier curva, anchura o pendiente sea transitable por todos los vehículos.

## Límites y mantenimiento

- Archivo de hasta 12 MiB, 20 000 puntos originales y 256 rutas/segmentos. No se truncan archivos que excedan el límite.
- Hasta 512 puntos editables. Si hace falta simplificar, se conservan los originales y se declaran las tolerancias de 1 m horizontal y 0,15 m vertical. Una ruta que no quepa con esas tolerancias necesita dividirse.
- Extensión local máxima de 40 km. Se utiliza una proyección métrica local WGS84, apropiada para un tramo; no es un globo geodésico. Se rechazan las zonas polares y cruces del antimeridiano no soportados.
- Dos puntos mínimos en rutas abiertas; cuatro en circuitos cerrados; recorrido mínimo de 120 m para aplicar.
- `geo` guarda origen/procedencia; `raw_route` conserva el original; `points` define la carretera editable. El origen vertical se resta para no desplazar toda la simulación a miles de metros y se restaura al mostrar cotas geográficas.
- El paisaje circundante continúa siendo generado por el juego. No se descargan edificios, vegetación real, señalización, peraltes, baches, texturas de calle ni una malla DEM del territorio.

Los módulos de `scripts/geo/` separan importación, proyección, simplificación, perfil, consulta de alturas, mapas e interfaz. `TrackSampler` y los componentes físicos siguen siendo comunes a los circuitos manuales y geográficos.

Para usar servicios propios sin modificar scripts, crea `user://geo_services.cfg`:

```ini
[providers]
map_url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
map_attribution="© OpenStreetMap contributors"
map_license_url="https://www.openstreetmap.org/copyright"
srtm_url="https://api.opentopodata.org/v1/srtm30m"
copernicus_url="https://api.open-meteo.com/v1/elevation"
```

El servidor alternativo debe respetar el formato de respuesta del proveedor reemplazado. En web necesita permitir el origen del juego mediante CORS. El servicio gratuito Open-Meteo está orientado a uso no comercial; para otro uso configura su servicio comercial o una instalación propia. Los límites de proveedores pueden cambiar.

## Fuentes técnicas

- [GPX, modelo de rutas y tracks · GDAL](https://gdal.org/en/stable/drivers/vector/gpx.html).
- [API, formatos y consulta de elevación · Open Topo Data](https://www.opentopodata.org/api/).
- [Conjuntos de datos y límites del servicio · Open Topo Data](https://www.opentopodata.org/).
- [Copernicus GLO-90 y API de elevación · Open-Meteo](https://open-meteo.com/en/docs/elevation-api).
- [Política de teselas y caché · OpenStreetMap Foundation](https://operations.osmfoundation.org/policies/tiles/).
- [JavaScriptBridge de Godot 4.6 para archivos en web](https://docs.godotengine.org/en/4.6/classes/class_javascriptbridge.html).
