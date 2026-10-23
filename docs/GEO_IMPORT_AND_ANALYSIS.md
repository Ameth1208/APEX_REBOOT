# Importación geográfica y perfiles — v0.2

Los módulos de `scripts/geo` convierten y analizan datos sin red ni interfaz. El análisis de una pista curva reutiliza `TrackSampler`, la misma clase pura que genera las muestras de la carretera. Un archivo importado no se convierte automáticamente en una medición fiable de una carretera real.

## API de integración

| Método estático | Resultado |
| --- | --- |
| `RouteImporter.parse(text, format, route_index=0)` | `{ok,error,routes,selected_route,definition,warnings}`; `format` admite `gpx`, `geojson`, `json` o `auto`. |
| `RouteImporter.from_points(points, name="Mi ruta real", source="map", closed=false)` | Mismo contrato, para puntos `{lat,lon,ele}`; `ele` puede ser `null`. |
| `RouteImporter.elevation_samples(definition, spacing_m=50)` | `{ok,error,points,requested_spacing_m,spacing_m,max_interval_m,warnings}`. |
| `RouteImporter.attach_original(definition, original, original_closed=false)` | Copia de la definición con observaciones originales y referencias remapeadas. |
| `GeoProjection.make_origin(lat,lon,alt=null)` | Metadatos del origen. |
| `GeoProjection.project(lat,lon,ele,geo)` | `{ok,error,x,y,z}`; metros locales, `y=null` cuando falta cota u origen vertical. |
| `GeoProjection.inverse(x,z,geo,y=null)` | `{ok,error,lat,lon,ele}`. |
| `RouteAnalyser.analyse(definition,window_m=100)` | Resumen construido, `constructed`, `raw`, `profile`, `raw_profile`, `comparison` y avisos. |

`routes` enumera `{index,name,source,point_count,elevation_count}`. Cada `trkseg`, cada `rte` y cada línea de un `MultiLineString` son selecciones independientes. No se unen pausas o pérdidas de señal de un GPX. Los nombres y la descripción de las fixtures dicen explícitamente que son sintéticas y que **no son mediciones de Bogotá**.

## Coordenadas y procedencia

El origen horizontal es el primer punto. `x` crece hacia el este, `z` hacia el sur y `y` hacia arriba. `geo.origin_alt_m` es la primera cota conocida, identificada por `origin_alt_source_index`; si no existe ninguna, ambos valores son `null` y `-1`, respectivamente. Así, un primer punto sin cota no provoca la invención de una elevación cero.

La proyección diferencial local usa los radios de curvatura del elipsoide WGS84 en la latitud del origen: `x = Δlon·N·cos(lat0)`, `z = −Δlat·M`, con ángulos en radianes. Usa `a=6378137 m` y `1/f=298.257223563`. Es una aproximación local; no se declara precisión topográfica ni se realiza una transformación de geoide o datum vertical. Se rechazan coordenadas no finitas, latitudes de valor absoluto igual o superior a 85°, cruces del antimeridiano y una extensión horizontal mayor de 40 km.

`definition.raw_route` conserva observaciones `{lat,lon,ele,elevation_source,source_index,...}`. `points` contiene la geometría editable `{x,y,z,width,bank,surface,raw_index,...}`. `control_route` es una instantánea geográfica de esos controles. El análisis y los nuevos muestreos consultan los **`points` actuales**, por lo que una edición no queda ocultada por una instantánea antigua.

Después de consultar cotas sobre muestras intermedias, crear la nueva definición con `from_points` y llamar a `attach_original`. Los controles que coinciden con una observación reciben su índice original; los puntos nuevos o desplazados quedan con `raw_index=-1`. Una coincidencia ambigua en un cruce necesita `original_raw_index` conservado; no se elige arbitrariamente otra rama. La altura de una observación puede diferir de la altura editada o calculada por DEM sin perder el vínculo horizontal. `attach_original` no modifica sus argumentos.

La procedencia del modelo se declara por separado de la original. Un proveedor debe añadir sus metadatos de servicio, resolución de la cuadrícula y datum cuando estén disponibles; la densidad de las muestras solicitadas no equivale a resolución del DEM ni a exactitud vertical. Las cotas GeoJSON siguen la tercera coordenada que el archivo entrega; no se verifican ni convierten referencias verticales entre fuentes.

## Límites y datos incompletos

- Hasta **8 MiB de texto UTF-8**, **20 000 puntos originales** por archivo y **256 rutas/segmentos**. Un exceso produce error; no se trunca el recorrido.
- Hasta **512 controles**. Si es necesario reducirlos, la simplificación respeta tolerancias de **1 m en planta** y **0,15 m en altura**, además de conservar límites de huecos de cota. Si hacen falta más controles para cumplirlas, se pide un tramo menor.
- Por defecto, importación **abierta**, interpolación **lineal**, anchura **12 m**, asfalto y peralte cero. Cerrar es una decisión explícita y requiere al menos cuatro controles. Un punto final igual al inicial se conserva en el original y se retira de los controles cerrados.
- Las cotas ausentes son `null`, nunca cero. `requires_elevation=true` bloquea la construcción hasta completar los datos o elegir de forma explícita una versión plana. Una altura inválida da error.
- Un salto vertical sin avance horizontal se conserva y activa `requires_geometry_review` como aviso; la validación de pista revisa la geometría actual antes de conducir.
- `elevation_samples` conserva todos los controles y añade puntos de planta intermedios con **cota desconocida**. El valor predeterminado es 50 m. Si excedería 512 muestras, aumenta la separación y comunica el valor efectivo. Una cota existente se conserva, sin interpolarla sobre las nuevas muestras.
- El análisis de una malla curva admite hasta 20 000 muestras, más el cierre explícito del perfil. Una malla mayor necesita aumentar `sample_spacing` o dividir el recorrido.

## Métricas y pendiente

`horizontal_distance_m` acumula `sqrt(Δx²+Δz²)`. `distance_3d_m` acumula `sqrt(Δx²+Δy²+Δz²)`. Ascenso y descenso acumulan por separado diferencias positivas y negativas de altura. No hay un filtro que transforme ruido de GPS en precisión: las métricas describen los datos recibidos.

La pendiente firmada es `100 × subida / distancia horizontal recorrida`. La ventana se centra en cada muestra y se desplaza hacia dentro al llegar a los extremos de una ruta abierta, conservando su longitud completa cuando cabe. En una ruta más corta se declara la longitud real usada. En un circuito cerrado la ventana puede atravesar la meta. Los máximos evalúan las posiciones en que cualquiera de los extremos de la ventana alcanza un vértice, evitando perder un máximo entre los centros de las muestras.

Una ventana que cruza cotas desconocidas o un salto vertical tiene `grade_pct=null`. Un punto repetido sin salto no crea una división por cero. `max_uphill_pct` es positivo o cero; `max_downhill_pct` es negativo o cero. Sin ninguna ventana válida son `null`.

Si falta alguna cota, los totales de longitud 3D y ascenso/descenso son `null`. Los campos `known_distance_3d_m`, `known_elevation_gain_m` y `known_elevation_loss_m` suman únicamente pares consecutivos con altura conocida. `elevation_coverage` mide la fracción de distancia horizontal cuyos extremos tienen cota; `point_elevation_coverage` mide puntos. Los mínimos y máximos se refieren a las alturas conocidas. Sin origen absoluto se ofrecen `min_height_m`/`max_height_m`; `min_elevation_m`/`max_elevation_m` quedan `null`.

Cada fila del perfil contiene `distance_m` horizontal, `height_m`, `elevation_m`, `grade_pct`, `window_m`, `grade_start_m`, `grade_end_m`, `control_index`, `raw_index`, `source_index` y `elevation_source`. En el perfil construido, `control_index` selecciona el control real asociado; en el original vale `-1` y se usa `raw_index`. Las filas interpoladas de una spline se identifican como `interpolated_model`.

`constructed` analiza exactamente la polilínea lineal o las muestras reales de `TrackSampler` para Catmull–Rom, incluidas sus posibles sobreoscilaciones. Las definiciones v1 mantienen sus valores predeterminados de circuito cerrado y Catmull–Rom. Con cotas incompletas no se crea una spline ficticia: `geometry_exact=false` y el perfil conserva los huecos. `raw` analiza las observaciones independientes; no adopta automáticamente un cierre que se haya añadido después al modelo.

## Verificación

```bash
godot --headless --path . --script tests/geo_checks.gd
godot --headless --path . --script tests/geo_limits_checks.gd
```

La suite principal comprueba 108 condiciones: proyección inversa; ejes; polos y antimeridiano; extensión; selección de segmentos; XML mal formado; coordenadas inválidas; cotas cero, negativas y ausentes; límites; preservación de picos; rechazo de simplificación destructiva; muestreo; pendiente de 10 %; arco horizontal frente a cuerda o distancia 3D; ascenso/descenso; repeticiones y verticales; ventana corta; cierre; procedencia; ediciones del modelo; muestreo Catmull y sobreoscilaciones. La segunda suite ejercita el límite de 20 000 observaciones y comprueba que ni el original ni su perfil se truncan.

## Referencias

- [TopoGrafix, esquema GPX 1.1](https://www.topografix.com/gpx/1/1/): puntos, cotas y segmentos continuos independientes.
- [IETF, RFC 7946](https://www.rfc-editor.org/rfc/rfc7946): GeoJSON, orden longitud/latitud, tercera coordenada y geometrías.
- [NGA, parámetros WGS84](https://earth-info.nga.mil/index.php?dir=wgs84&action=wgs84): semieje mayor y achatamiento.
- [Godot, XMLParser](https://docs.godotengine.org/en/stable/classes/class_xmlparser.html): lectura incremental del XML.
