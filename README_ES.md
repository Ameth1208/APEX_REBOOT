# APEX REBOOT · 0.3.2

**Conducción offline y diseño de circuitos tridimensionales en Godot 4.6.3.** El proyecto reúne los cuatro vehículos aportados, cuatro circuitos editables, carreras contra IA, campeonato, conducción de moto, aerodinámica, rebufo y personalización visual. El código se organiza por responsabilidades y los vehículos se configuran mediante perfiles JSON.

## Novedades de esta versión

**La actualización 0.3.2 revisa la pista, el garaje, las ruedas y los costes de ejecución.** Incluye:

- **Garaje con el vehículo como protagonista:** colección de modelos, páginas **Sesión / Diseño**, acción Conducir siempre accesible y tipografía Barlow compartida con los instrumentos. Los selectores admiten flechas de teclado o mando y muestran las opciones pertinentes a cada modo.
- **Edición estable:** escribir dentro del nombre de la pista conserva cursor y selección; los campos numéricos mantienen la entrada en curso. Cambiar un nombre deja de recalcular el perfil de elevación y de duplicar las capas geográficas originales en cada pulsación.
- **Calzada con mejor acabado:** materiales de asfalto y humedad revisados, detalle filtrado a distancia, bordillos bajos biselados con colisión y bandas definidas en metros. La geometría se divide en tramos para que el motor pueda descartar los que quedan fuera de la cámara. Se conservan puntos, alturas, superficies y texturas propias del circuito.
- **Polonuevo–Baranoa en el catálogo:** puedes elegir la pista convertida directamente desde el garaje. Se identifica como plana porque el archivo original no contiene alturas.
- **Ruedas coherentes con sus contactos:** corrección de la escala radial y posición de los ejes del modelo Senna, alineación de los cuatro perfiles, dirección delantera con ángulo interior/exterior diferenciado y animación de rueda bloqueada. La suspensión del Fórmula incorpora un reposo específico y tope progresivo para soportar la carga aerodinámica sin agotar enseguida su recorrido.
- **Menos trabajo por consulta de pista:** la búsqueda de posición reutiliza geometría precalculada y una ventana alrededor de la posición anterior, con recuperación si esa referencia deja de servir. Las consultas siguen considerando las tres dimensiones y los distintos niveles de un puente.
- **Calidad Automático y diagnóstico F8:** adaptación del renderizado 3D, interfaz a resolución nativa e informe local para medir el comportamiento en tu equipo. La interpolación de presentación suaviza cámara y vehículos entre pasos físicos; la simulación conserva **120 Hz**.

El [informe de verificación 0.3.2](docs/VALIDATION.md) documenta las correcciones reproducidas, pruebas, medida de CPU y estado de cada plataforma. La física continúa usando parámetros estimados; esta revisión no equivale a una calibración con telemetría de los vehículos reales.

El HUD de conducción conserva clasificación arriba a la izquierda, tiempos arriba a la derecha, minimapa abajo a la izquierda e instrumentos al centro inferior, con marcha destacada y pedales rojos independientes. Las asignaciones se consultan en Ajustes y el detalle físico con F3. El [manual del HUD](docs/HUD.md) explica cada indicador.

## Funciones del juego

**Daños con consecuencias, caída física de moto, recuperación de IA mediante conducción, clasificación completa y ajustes guardados de controles y cámara.** La versión 0.3 incorpora:

- Impactos que afectan a motor, dirección y aerodinámica; caída de moto y recuperación explícita. El HUD muestra daño y estado mecánico.
- Marcas de neumáticos, humo, polvo, salpicaduras y chispas según contacto y superficie. Sonido procedural de golpe, deslizamiento y motor según cilindros.
- Rivales que anticipan tráfico, comprueban carriles, adelantan y vuelven a su línea. Se recuperan con marcha atrás; los irreparables abandonan. Tres niveles de dificultad.
- Pantalla de resultados con clasificación, tiempos y DNF, y retirada desde la pausa.
- Reasignación de diez acciones de teclado; curvas y zonas muertas para dirección y pedales; respuesta de giro configurable.
- FOV, seguimiento de inclinación y movimiento de cámara ajustables. Pintura y decoración recordadas por vehículo.
- Materiales de suelo con relieve y respuesta a humedad; cielo, iluminación de noche, bosque y señalización revisados. Equilibrado usa sombras de 2048 con dos cascadas y Alto, 4096 con cuatro.

Se conservan las rutas desde mapas, GPX y GeoJSON, el perfil de altura y pendientes, los recorridos con salida y llegada, el piloto humano articulado y los pedales rojos con porcentajes. [Rutas reales](docs/REAL_ROUTES.md) explica importación y análisis. [Compilar con Docker](docs/BUILD_DOCKER.md) contiene los comandos, caché y automatización de builds. [Verificación](docs/VALIDATION.md) distingue las pruebas ejecutadas y los límites de cada plataforma.

## Jugar en Windows o Linux

Los paquetes compilados incluyen el motor necesario. **No necesitas instalar Godot para jugar.**

1. Descarga el ZIP correspondiente a tu sistema **x86_64**.
2. **Extrae todo el ZIP** en una carpeta. No abras el juego desde la vista comprimida del explorador.
3. Conserva el ejecutable y `APEX_REBOOT.pck` juntos, con el resto de los archivos del paquete.
4. En Windows, abre `APEX_REBOOT.exe`. En Linux, ejecuta `APEX_REBOOT.x86_64`.

En Linux, si el archivo perdió el permiso de ejecución al extraerlo:

```bash
chmod +x APEX_REBOOT.x86_64
./APEX_REBOOT.x86_64
```

El renderizador Compatibility depende del controlador gráfico y del equipo. Empieza con calidad **Automático**; si necesitas reducir más la carga, prueba **Rendimiento**, menos rivales o una ventana menor. El Porsche es especialmente detallado.

La inspección de los recursos confirma el coste de esos modelos: el Porsche reúne **361 superficies y 1 721 938 triángulos en su geometría base**; la Yamaha con piloto, 109 superficies y 392 883 triángulos. El motor ya dispone de niveles de detalle para reducir esa geometría a distancia. Estas cifras cuentan el modelo completo antes de descartar partes y elegir detalle; no son los triángulos visibles de cada cuadro ni una medida de FPS. [Presupuesto de modelos](docs/model_render_budget_v032.json) conserva el diagnóstico. Se mantienen los materiales Original, las decoraciones, las ruedas y los huesos del piloto.

### Calidad de imagen y diagnóstico

En **Ajustes → Imagen y sonido → Calidad de imagen** hay cuatro opciones:

| Calidad | Comportamiento |
| --- | --- |
| Automático | Busca un objetivo de 60 FPS ajustando de forma gradual la escala 3D entre 70 y 100 %, sombras y distancia del decorado. Espera a que la carga sea sostenida para cambiar y recupera detalle cuando hay margen. |
| Rendimiento | Mantiene la escala 3D al 80 %, con menor coste de sombras, antialiasing y decorado. |
| Equilibrado | Escala 3D al 100 %, MSAA 2× y sombras equilibradas. |
| Alto | Escala 3D al 100 %, MSAA 4× y mayor detalle de sombras y decorado. |

El HUD y los menús mantienen su resolución, y los cuatro modos conservan la física a 120 pasos por segundo. **60 FPS es el objetivo del ajuste automático, no un rendimiento garantizado.** La mejora medida de esta revisión corresponde a una operación concreta de CPU: 1200 consultas de posición en la ruta Polonuevo–Baranoa pasaron de una mediana de 1280,274 ms a 23,096 ms, con el mismo resultado acumulado. Ese factor de 55,4× no representa el aumento de FPS del juego completo; el método y sus límites están en [Verificación](docs/VALIDATION.md).

Después de conducir, pulsa **F8** para guardar `APEX_rendimiento.json`. En Windows y Linux queda en `user://diagnostics/`, dentro del directorio de datos del juego; en Web se solicita su descarga. Incluye CPU, adaptador gráfico, calidad, resolución, escala 3D, FPS medios, tiempo de cuadro del percentil 95, llamadas de dibujo y temporizaciones disponibles de CPU/GPU de los últimos 1200 fotogramas en pista. Si la GPU no ofrece su temporización, ese dato queda vacío. El informe se guarda localmente y no se envía por red. La ubicación de los datos por sistema se explica en [Arquitectura](docs/ARCHITECTURE.md).

## Primera sesión

Elige **Porsche → Costa Clara → Contrarreloj → Sport → Día · seco**, mantén el cambio automático y pulsa **CONDUCIR**. W/S aceleran/frenan, A/D giran, C cambia cámara y Esc pausa. [Controles](docs/CONTROLS.md) contiene todas las asignaciones de teclado y mando.

La conducción, la IA y el análisis de rutas con cotas incluidas funcionan sin cuenta ni conexión. La conexión se utiliza para descargar herramientas, mostrar cartografía y consultar alturas cuando se solicitan desde el editor.

## Vehículos y apariencias

| Vehículo integrado | Categoría | Configuración |
| --- | --- | --- |
| Porsche 992 GT3 RS · 2024 | GT de carretera | Cuatro ruedas, motor trasero y carga aerodinámica elevada. |
| Yamaha YZF · 2021 | Moto supersport | Dos contactos y piloto virtual que solicita inclinación. |
| Ferrari 312T · 1976 | Fórmula clásica | Monoplaza clásico con perfil mecánico propio. |
| Fórmula Senna · 1991 | Fórmula 1991 | Perfil de referencia inspirado en el MP4/6. |

La identificación R7 se infiere del archivo Yamaha; no está certificada. La Ferrari conserva la denominación aportada. [Vehículos](docs/VEHICLES.md) explica identificación, dimensiones y parámetros.

Cada vehículo ofrece **Original y tres decoraciones gráficas propias** con motivos distintos. Hay siete colores base: **rojo, azul, amarillo, blanco, negro, verde y plata**, combinables con decoraciones. Para recuperar el aspecto integrado inicial, selecciona **Original en pintura y decoración**. Los cambios afectan a materiales seleccionados, conservando el archivo fuente. El garaje recuerda la combinación de pintura y decoración de cada vehículo al cambiar de modelo y al volver a abrir el juego.

## Circuitos y modos

| Circuito | Longitud aproximada | Características |
| --- | ---: | --- |
| Costa Clara | 3.164 km | Curvas fluidas, rectas rápidas y cambios de rasante. |
| Sierra Alta | 3.678 km | Desnivel de 66 m, viaductos y cruces a distintas alturas. |
| Laguna Técnica | 3.614 km | Enlazadas y frenadas para practicar con motos y coches. |
| Polonuevo–Baranoa (plano) | 14.458 km | Circuito importado de RacetrackDesign. Conserva el trazado convertido; las alturas originales son desconocidas y se usa una base plana explícita. |

Las longitudes se calculan sobre la trayectoria 3D y cambian al editarla. La calzada tiene espesor, laterales, parte inferior y colisión.

| Modo | Funcionamiento |
| --- | --- |
| Libre | Conducción sin rivales y sin un final práctico por número de vueltas. |
| Contrarreloj | Sesión individual sobre las vueltas seleccionadas, con mejor vuelta válida. |
| Carrera | Carrera con hasta cinco rivales IA y número de vueltas configurable. |
| Campeonato | Cuatro etapas consecutivas que guardan puntos, medallas y desbloqueos. |

El campeonato empieza en **Escuela GT** —Porsche/Costa Clara, dos vueltas— y continúa con **Equilibrio** —Yamaha/Laguna Técnica, dos—, **Herencia** —Ferrari/Sierra Alta, tres— y **La última luz** —Fórmula 1991/Costa Clara de noche, tres—. Cada etapa fija vehículo, pista y rivales.

Para avanzar debes completar todas las vueltas válidas sin utilizar el piloto automático F4. Activarlo y apagarlo después sigue dejando registrada su utilización en esa sesión. Las puertas de control se recorren en orden; recolocar el vehículo limpia las puertas acumuladas y no puede fabricar una vuelta. Las salidas prolongadas de pista invalidan el tiempo. Una carrera puede terminar con vueltas inválidas, pero ese resultado no concede progreso de campeonato.

## Física, rebufo y conducción

La simulación funciona a 120 pasos físicos por segundo, con cuatro contactos de suspensión en coches y dos en motos. Muelles, amortiguadores, frenada, transmisión y neumáticos actúan sobre cuerpos físicos. Pendiente, peralte, superficie y humedad cambian la respuesta. Las ruedas visibles comparten la posición de contacto y el giro de la simulación: en los coches, la rueda interior de la curva gira más que la exterior. Al extenderse por completo una suspensión, su consulta de suelo termina en el alcance de la rueda.

La resistencia del aire y la carga aerodinámica dependen de la velocidad y del perfil. **El rebufo reduce la resistencia; el aire sucio puede reducir la carga**, afectando al agarre disponible. Se calcula para todos los participantes y respeta su separación lateral, dirección y altura. Los vehículos situados en distintos niveles de un puente no comparten una estela por coincidir en el mapa.

La IA usa esa misma física: controla pedales/dirección, planifica frenada según perfil, humedad y pendiente, anticipa tráfico, verifica el carril antes de adelantar y regresa a su trazada. Ante un atasco frena, retrocede y se realinea; no se teletransporta. Los rivales incapacitados aparecen como DNF. F4 permite observarla conduciendo tu vehículo. Es un controlador determinista con márgenes, sin garantía de vuelta perfecta u óptima.

En Ajustes hay cuatro páginas: **Conducción, Cámara, Controles e Imagen y sonido**. Puedes cambiar transmisión, dificultad, respuesta/curvas de entrada, zonas muertas, trazada orientativa, carga aerodinámica, agarre, humedad, volumen, pantalla completa y calidad. **Asistida** incluye ABS, control de tracción y estabilidad; **Sport** conserva ABS; **Experta** retira esas ayudas. El equilibrio virtual de la moto mantiene la conducción normal; se pierde al caer. Los impactos afectan a la capacidad de acelerar, girar y generar carga. R repara y recoloca, invalidando el intento actual. [Daños y efectos](docs/VEHICLE_CONDITION.md) explica el comportamiento.

Son modelos de simulación jugable: no están calibrados mediante CFD, neumáticos ensayados, telemetría de fabricantes ni un banco de pruebas de dinámica de moto. La geometría visual no produce automáticamente sus coeficientes físicos. Las hipótesis y las pruebas reproducibles están en [Física e IA](docs/PHYSICS_AND_AI.md).

## Editor, cámaras y guardado

Con **F2** puedes añadir/mover puntos y ajustar elevación, ancho, peralte, espesor y superficies. Hay asfalto, hormigón, grava, tierra, hierba y arena, con texturas procedurales o imágenes propias. **Aplicar y conducir** cambia la sesión; **Guardar** conserva el circuito. Aplicar un diseño durante el campeonato pasa a modo Libre. Consulta [Editor de circuitos](docs/TRACK_EDITOR.md) para importar/exportar JSON y texturas. **Ruta real · mapa / GPX…** permite dibujar sobre cartografía o importar coordenadas; el panel inferior analiza altura y pendientes. Las rutas abiertas tienen salida y llegada independientes.

C recorre persecución, capó/depósito, piloto, cinemática y orbital, con posición de piloto por modelo. En la moto, Persecución, Depósito y Piloto acompañan su inclinación sin sumarla dos veces. Puedes reducir ese seguimiento hasta mantener el horizonte y elegir un FOV vertical de 50–95°. El movimiento visual por aceleración e impactos también se puede desactivar. El HUD muestra acelerador, freno y freno de mano/trasero por separado, siempre entre 0 y 100 %. La interfaz escala con la ventana y amplía su área útil según la relación de aspecto. F6 activa modo foto, ratón derecho/rueda encuadran y F12 guarda. N alterna día/noche; L controla faros.

Preferencias, campeonato, circuitos e imágenes se guardan en el directorio de datos del usuario, no en el ZIP. La estructura y cómo conservarla al actualizar están en [Arquitectura](docs/ARCHITECTURE.md).

## Editar y compilar el código fuente

Extrae el ZIP fuente, abre `project.godot` con **Godot 4.6.3**, espera la importación inicial y pulsa **F5 para ejecutar el juego completo**.

Con Docker Compose, desde la carpeta que contiene `project.godot`:

```bash
docker compose run --rm build
```

Genera Windows x86_64, Linux x86_64 y Web. En Linux, `bash COMPILAR_DOCKER.sh` adapta los permisos a tu usuario; en Windows, `COMPILAR_DOCKER.bat`. Docker se usa para exportar; no hace falta para jugar ni forma parte de la simulación. Consulta [la guía](docs/BUILD_DOCKER.md) para requisitos, caché y compilación de una sola plataforma.

También puedes generar los ejecutables desde los asistentes incluidos:

- **Windows:** abre `EXPORTAR_WINDOWS.bat`.
- **Linux x86_64:** ejecuta `bash EXPORTAR_LINUX.sh`. Necesita Bash, `curl`, `unzip`, `awk` y `sha512sum`.

Los asistentes descargan el editor y las plantillas oficiales de Godot 4.6.3, comprueban SHA-512 y reutilizan su caché. Las plantillas requieren una descarga inicial de aproximadamente **1.2 GB**, además del editor. La primera importación de los modelos puede tardar. Los resultados quedan en `build/Windows/` y `build/Linux/`.

También se entrega una exportación Web para ordenador. Extrae su ZIP y sigue `LEEME_WEB.txt`: debes servir sus archivos por HTTP, por ejemplo con el servidor Python incluido. La verificación de navegador y el historial de pruebas de rutas reales están documentados en [VALIDATION.md](docs/VALIDATION.md), con la versión a la que corresponde cada ejecución. No se certifica compatibilidad con móviles o todos los navegadores. El ejecutable nativo es la distribución principal.

Para volver a exportarla desde el fuente: `bash EXPORTAR_LINUX.sh --web` o `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/export.ps1 -Web`. No abras el `index.html` generado directamente como archivo local.

## Modelos aportados y mantenimiento

La autoría y las condiciones encontradas en los modelos se conservan en [Avisos de terceros](assets/vehicles/THIRD_PARTY_NOTICES.md). Las condiciones de los modelos son independientes del código del juego; consulta ese documento antes de redistribuirlos o darles un uso comercial.

Para ampliar vehículos o pistas, empieza por sus perfiles JSON y catálogos. [Arquitectura](docs/ARCHITECTURE.md) indica qué módulo modificar y qué pruebas ejecutar, sin duplicar el controlador completo para cada vehículo.

El informe de [Verificación](docs/VALIDATION.md) resume las pruebas realizadas y sus límites. La licencia del motor y los avisos de sus dependencias están en `licenses/`.
