# Verificación de APEX REBOOT

## Entrega 0.3.2 · acabado, edición y rendimiento · 20 de octubre de 2026

Esta revisión corrige errores reproducidos de ruedas, suspensión, edición y generación de pista; añade calidad adaptativa e instrumentación del rendimiento. Se ejecutaron las pruebas siguientes con Godot **4.6.3.stable.official.7d41c59c4**. La simulación mantiene **120 Hz**. El resumen estructurado está en [verification_v032.json](verification_v032.json). Las secciones 0.3.1 y anteriores conservan sus resultados históricos; no representan una repetición de esas exportaciones o sesiones sobre 0.3.2.

### Medida de CPU y calidad de presentación

Se comparó la búsqueda de posición sobre la misma ruta **Polonuevo–Baranoa (plano)**, de **14 457,773 m** y **3722 muestras**. Cada ejecución realiza 60 consultas de calentamiento y cinco rondas de 1200 consultas con una referencia de posición anterior. Se usaron el mismo motor, ruta, posiciones y resultado numérico acumulado en 0.3.1 y 0.3.2.

| Medida de la operación de CPU | 0.3.1 | 0.3.2 |
| --- | ---: | ---: |
| Mediana de 1200 consultas | 1280,274 ms | 23,096 ms |
| Tiempo medio por consulta dentro de esa ronda | 1066,895 µs | 19,247 µs |
| Resultado acumulado, sin redondear | 43358507.1956789 | 43358507.1956789 |

La operación medida mejora **55,4×**. Este es un microbenchmark de consultas en un hilo de CPU: **no mide renderizado, FPS del juego, latencia de entrada ni rendimiento de una GPU de usuario**. Los resultados dependen del procesador y la carga del entorno. La optimización precalcula los segmentos, consulta una ventana local cuando dispone de una referencia útil y recupera la búsqueda global cuando esa referencia deja de ser válida. Las distancias siguen evaluándose en 3D.

[benchmark_route_queries_v032.json](benchmark_route_queries_v032.json) conserva las cinco rondas, alcance y método. Para medir la versión actual, después de importar el proyecto:

```bash
godot --headless --path . --script tools/benchmark_route_queries.gd -- data/tracks/polonuevo_baranoa.json
```

El modo **Automático** busca 60 FPS con escala 3D **0,70–1,00**, histéresis y cambios de detalle de sombras/decorado. Mantiene resolución de interfaz y frecuencia física; no reduce los pasos de simulación para aparentar más FPS. Los modos fijos son Rendimiento, Equilibrado y Alto. La interpolación de presentación mantiene cámara y vehículos entre los estados físicos.

**F8** guarda las medidas de los últimos 1200 cuadros en pista en `user://diagnostics/APEX_rendimiento.json`; Web solicita la descarga del mismo archivo. El informe incluye CPU, adaptador gráfico, renderizador, ventana, escala 3D, FPS medios, p95 de tiempo de cuadro, llamadas de dibujo y tiempos disponibles de renderizado y física. La temporización GPU se indica como `null` cuando el controlador no la proporciona. No se calcula un FPS cuando todavía no se han recogido cuadros, y el informe no se envía por red. El objetivo de 60 FPS no constituye una garantía de rendimiento.

### Pruebas de interfaz y pista

| Prueba ejecutada | Resultado y alcance |
| --- | --- |
| `tests/ui_editing_checks.gd` | **PASS, 52 comprobaciones**, cero fallos. Introduce eventos de texto en mitad de un nombre, verifica orden, cursor, selección, foco, deshacer/rehacer y borrador numérico. El nombre no vuelve a calcular elevaciones y el historial comparte capas originales inmutables sin mezclar los puntos editables. |
| Garaje, editor, ajustes y pausa | Incluidos en esas 52 comprobaciones: selectores con flechas, opciones pertinentes a cada modo, páginas Sesión/Diseño y menús dentro de la ventana. Garaje en 960×540, 1024×768, 1280×720, 1920×1080 y 2560×1080; editor en 960×540, 1280×720 y 1920×1080; ajustes y pausa en sus tamaños mínimos probados. |
| `tools/hud_layout_probe.gd` | **PASS, 752 comprobaciones**, cero fallos, repetidas sobre esta revisión. HUD real con telemetría sintética; cuatro escenarios y cuatro relaciones de ventana. Comprueba composición, límites, instrumentos y pedales, sin conducción física ni capturas nuevas en este pase. |
| `tests/track_finish_checks.gd`, Polonuevo–Baranoa | **PASS:** 58 mallas visibles de asfalto, extensión máxima de una malla 329,988 m y 29 776 triángulos de calzada. **360 consultas de contacto, cero huecos; 120 de 120 contactos de bordillo.** Coinciden las caras de colisión y dibujo de la carretera, los triángulos respetan sus normales y la geometría editable de entrada permanece intacta. |
| `tests/track_finish_checks.gd`, circuito sintético de 14 km | **PASS:** 66 mallas de calzada, extensión máxima de 326 m, cero huecos en 360 consultas y 120 de 120 contactos de bordillo. Incluye uniones cóncavas y plegadas, UV longitudinal en metros, material compartido y transmisión de humedad. |

El garaje usa Barlow y organiza colección, sesión y diseño dejando espacio para el modelo. El HUD mantiene los pedales rojos separados. Los cambios de acabado usan detalle de superficie compartido con filtrado, variación de asfalto/humedad y bordillos biselados físicos. El troceado de calzada permite descartar mallas fuera de la cámara; no modifica por sí mismo los puntos, alturas o distancias del recorrido. También se revisaron las capturas nativas: asfalto, pianos y humedad se renderizan correctamente. Esta revisión visual no mide el rendimiento de una GPU de usuario.

Polonuevo–Baranoa se incluye como cuarta pista del catálogo. Conserva **214 puntos editables** y **2163 muestras originales** del archivo convertido. Se mantiene la condición de altura desconocida y el plano explícito del archivo: no se presenta una elevación artificial como medición real.

### Ruedas, contacto y conducción del Fórmula

Se reprodujeron tres defectos del modelo Senna: una sección radial visual de aproximadamente **0,782 × 0,672 m**, ejes visuales desplazados aproximadamente **0,47 m** respecto de los contactos y una suspensión que sobrepasaba sus **0,20 m** de recorrido declarado con la carga aerodinámica del perfil. Las ruedas se corrigen en ejecución, compartiendo geometría de contacto, sin reescribir los archivos fuente de los modelos ni sus materiales Original.

| Prueba ejecutada | Resultado y alcance |
| --- | --- |
| `tests/wheel_rig_checks.gd` | **PASS, 79 comprobaciones**, cero fallos. Carga los cuatro modelos reales del proyecto, verifica 4/4/4/2 ruedas independientes y alineación con el contacto dentro de 2 mm. Mide vértices importados durante 16 ángulos de giro, rodadura con signo, bloqueo, dirección interior/exterior y extensión de suspensión. |
| Variación vertical durante el giro | Máximo medido: Senna **5,38 mm**, Porsche **0,27 mm**, Ferrari **0,68 mm** y Yamaha **0,64 mm**. La rueda Senna queda con diámetros radiales nominales de 0,66 × 0,66 m; la pequeña variación residual corresponde a la malla. |
| `tests/formula_handling_checks.gd` | **PASS, 121 comprobaciones**, cero fallos. Punto de potencia, límite de potencia en barrido de RPM, ancho de vías, centro de giro de dirección Ackermann, reposo, cuatro contactos y pérdida de contacto por encima del alcance real de la suspensión. |
| Suspensión del Senna a 306 km/h iniciales | En una recta física de tres segundos, la altura mínima pasó de **0,3378 m** antes del ajuste a **0,4394 m** después; compresión máxima final **0,1092 m**, dentro del recorrido de 0,20 m. Cuatro contactos, sin daño y 297,62 km/h al terminar. Es un escenario de prueba del modelo, no una medición del MP4/6 real. |
| `tests/physics_checks.gd` | **PASS:** reposo de coche/moto, aceleración, frenada, giro, inclinación de moto y pendiente/peralte. |
| `tests/collision_checks.gd` y `tests/vehicle_condition_checks.gd` | **PASS:** barreras, transferencia de impulso entre parejas coche/moto, obstáculos sólidos, daño, caída y reparación. Las envolventes de colisión acompañan el desplazamiento de los modelos. |

El hundimiento estático de **0,035 m** del Fórmula es un parámetro de simulación estimado. El tope progresivo limita el fondo de suspensión y las consultas de rueda terminan al alcanzar la extensión disponible. La dirección delantera diferencia rueda interior/exterior y comparte ese ángulo con las fuerzas y el aspecto visual. Las ruedas bloqueadas dejan de rodar visualmente.

La curva de motor alcanza el punto nominal del perfil de **540,6 kW a 13 500 rpm**; antes sólo entregaba 454,312 kW a ese régimen. El régimen de potencia y las vías de **1824/1669 mm** proceden de [Honda: McLaren Honda MP4/6, 1991](https://global.honda/en/F1/machine/1991_McLarenHondaMP46/). La interpolación entre los puntos nominales, neumáticos, amortiguadores y aerodinámica siguen siendo aproximaciones: **no hay calibración con telemetría, CFD ni ensayos de neumáticos del vehículo real**.

La regresión `tests/open_route_ai_checks.gd` volvió a completar la etapa sintética con los cuatro perfiles, frenando tras la llegada y sin recuperación:

| Vehículo | Tiempo simulado | Error lateral máximo | Recuperaciones |
| --- | ---: | ---: | ---: |
| Porsche 992 GT3 RS | 27,508 s | 0,529 m | 0 |
| Yamaha YZF | 33,492 s | 0,482 m | 0 |
| Ferrari 312T | 26,058 s | 0,640 m | 0 |
| Fórmula Senna | 23,308 s | 0,708 m | 0 |

Estos tiempos son resultados de la escena de pruebas y sus ajustes; no garantizan vuelta perfecta, realismo certificado ni que la IA resuelva cualquier trazado importado. Los registros de ruedas, física y regresiones están en `tooling/handling-review/`; los de interfaz, en `tooling/ui-polish/` y `tooling/ui-polish-hud/`; los de geometría, en `tooling/track-polish/`, fuera de los paquetes finales. Los scripts sí se incluyen en el fuente. Se ejecutan con `godot --headless --path . --fixed-fps 120 --script tests/NOMBRE.gd`.

### Comprobaciones de integración y distribución

`tests/performance_checks.gd` terminó con **PASS**, 53 consultas comparadas con una proyección 3D independiente y cero fallos/advertencias. Incluye puentes, cierre de vuelta, referencias inválidas, segmento final de 2 cm, segmento degenerado, pico aislado de 250 ms, carga sostenida, histéresis, resolución de UI y física a 120 Hz. Las regresiones de controles/cámara (23), cámara de moto (18), reglas de carrera y aerodinámica/rebufo también pasaron.

Las copas de árboles usan ahora grupos de hojas con huecos y ramas, atlas compartido con mipmaps y dos superficies. Cada árbol de copa ancha baja de 3260 a 1468 triángulos; la conífera conserva 2404. [foliage_budget_v032.json](foliage_budget_v032.json) conserva medidas y límites: el recorte alfa y las llamadas de dibujo también afectan al coste, por lo que contar menos triángulos no equivale a medir más FPS.

Las capturas de conducción utilizan el motor físico y acelerador analógico al 65 %; mostraron 93,476 km/h en el Fórmula y 43,852 km/h en la moto, con sus porcentajes reales en el HUD. El harness permite 128 pasos físicos máximos por cuadro para compensar el renderizado por software; el juego distribuido conserva su configuración normal. Las imágenes son comprobación visual y funcional, no un benchmark gráfico.

### Estado de cierre de esta revisión

El [diagnóstico de modelos](model_render_budget_v032.json) contó los recursos de la escena de cada vehículo después de configurar ruedas y piloto. El Porsche tiene **361 superficies / 1 721 938 triángulos base**, con LOD en 294 superficies; la Yamaha con piloto, **109 / 392 883**, con 99 mallas vinculadas a huesos y LOD en 97 superficies. Senna tiene 70 / 36 876 y Ferrari, 27 / 74 387. Son sumas de geometría completa a máximo detalle, contada una vez por superficie: no equivalen a lo visible, a las pasadas de sombras, a llamadas de dibujo ni a un tiempo GPU medido. Se conservan los LOD importados y las vinculaciones de materiales, ruedas y huesos. Una futura reducción del Porsche debe mantener esas propiedades y medirse en renderizado; unir mallas descartando los LOD existentes puede empeorar el resultado.

| Comprobación de distribución o presentación | Estado 0.3.2 |
| --- | --- |
| Inspección de capturas nativas de mundo, garaje y conducción | **PASS:** capturas nativas actuales de garaje, editor, pista seca/mojada y conducción de Fórmula/moto de día/noche; Godot 4.6.3 y OpenGL Compatibility con Mesa por software. |
| Exportación Windows x86_64, Linux x86_64 y Web | **PASS:** exportaciones release con las plantillas oficiales verificadas, sin errores de script/exportación. |
| Ejecutable Linux final | **PASS:** arranque headless de 120 cuadros y prueba visual independiente desde el ejecutable/PCK: Polonuevo, acelerador 65 %, movimiento y exportación F8; salida 0 y cero fallos. La prueba permite 128 pasos físicos por cuadro sólo durante QA con Mesa por software. |
| Navegador | **PASS con observaciones no bloqueantes:** Chrome Headless Shell 151 / WebGL 2 / SwiftShader. Garaje, entrada en pista/HUD, pausa, regreso y editor; texto insertado en medio: «Costa Nueva Clara». Después de corregir glifos, otro perfil verificó arranque, botón y descarga F8. Cero excepciones JavaScript y cero HTTP 4xx/5xx. |
| Empaquetado final, integridad y hashes de los ZIP | Las entradas de los cuatro paquetes están validadas. `SHA256SUMS.txt` identifica los ZIP entregados y el informe externo `APEX_REBOOT_v0.3.2_Verificacion.json` registra su comprobación CRC y SHA-256. |
| Windows nativo | **NO EJECUTADO:** no hay un entorno Windows funcional disponible para esta validación. |
| Docker Engine y GitHub Actions | **NO EJECUTADOS.** No hay Docker Engine disponible; no se ha lanzado el workflow remoto. |
| FPS, estabilidad y latencia en una GPU de usuario | **NO MEDIDOS.** La medida de CPU anterior no certifica 60 FPS ni calidad o rendimiento de consola. |

[README_ES.md](../README_ES.md) conserva las instrucciones para jugar y [BUILD_DOCKER.md](BUILD_DOCKER.md) explica compilación, caché y exportación por plataforma. Docker se utiliza para compilar; no forma parte de la ejecución de la física.

El [informe de navegador](web_smoke_v032.json) conserva tres observaciones: advertencia de occlusion culling deshabilitado en la plantilla Web; una solicitud `index.pck` con HTTP 200 seguida de `net::ERR_ABORTED`, pese a cargar los recursos y completar el flujo, cuya causa no se estableció; y cierre deliberado del primer harness tras validar el cursor, durante un clic opcional posterior. El segundo arranque terminó sin errores del harness. Después de esa sesión se trasladó el helper de QA nativo y su rama explícita `--qa-distribution`; el flujo Web normal no cambió. No se repitió Chromium sobre ese PCK exacto: el informe diferencia sus hashes de los del artefacto realmente probado. F8 se probó allí desde el garaje: cero muestras de conducción y FPS/p95 vacíos, correctamente.

## Entrega 0.3.1 · rediseño del HUD · 20 de octubre de 2026

Esta revisión cambia la presentación de la conducción: clasificación, tiempos, minimapa, instrumentos, pedales y avisos. No introduce cambios en la dinámica ni una calibración nueva de los vehículos. Los resultados 0.3 y anteriores se conservan debajo como historial; sus referencias a una guía permanente de teclas describen aquella interfaz.

### Pruebas del HUD y de integración

| Prueba ejecutada | Resultado y alcance |
| --- | --- |
| `tools/hud_layout_probe.gd` | **PASS, 752 comprobaciones**, cero fallos. Instancia el HUD real con cuerpos `RigidBody3D`, seguimiento de vueltas y clasificación, pero aporta telemetría sintética y no carga modelos ni ejecuta una prueba de conducción. Comprueba pedales 0/65/30/40/100 %, R/N, límite de RPM, textos y avisos, telemetría opcional, tiempos y llegada. |
| Tamaños y modos del HUD aislado | Carrera de moto, contrarreloj de coche, moto en Libre y etapa abierta de coche, en **960×540, 1024×768, 1920×1080 y 2560×1080**. Comprueba límites de los paneles, ausencia de intersecciones y centrado de instrumentos, tanto en vista normal como con telemetría y daño visibles. Produjo 16 imágenes temporales de la fixture; no son capturas de una carrera real. |
| `tests/hud_intervals_checks.gd` | **PASS, 21 comprobaciones**, cero fallos. Intervalos desde tiempos registrados a la misma distancia, interpolación entre muestras, falta de cobertura, reinicio, invalidación, marcha atrás, saltos, DNF, llegada, vehículos detenidos y límite del historial. No calcula segundos ficticios dividiendo distancia por velocidad. |
| `tests/hud_position_checks.gd` | **PASS, 5 comprobaciones**, cero fallos. Reproduce una posición de sesión todavía inicial durante la cuenta atrás y comprueba que cabecera y fila del jugador comparten clasificación. También verifica un adelantamiento y el intervalo entre refrescos de la tabla. |
| `tools/v03_feature_probe.gd`, repetido sobre 0.3.1 | **PASS, 32 comprobaciones**, cero fallos, en modo **headless**. Abre la aplicación, reasigna una tecla, entra en carrera con seis vehículos, conduce mediante eventos de teclado del motor, comprueba pedales y ausencia de guía permanente, abre pausa/ajustes, termina en DNF, vuelve al garaje y verifica preferencias guardadas. |
| `tools/hud_race_capture.gd` | **PASS**, cero fallos. Cuatro capturas nativas del juego real en **1600×900**: coche, moto, moto de noche y telemetría F3. La inspección visual confirma 87 km/h en el coche y 41 km/h en la moto, ambos con acelerador al 65 %. La velocidad procede de la conducción simulada; no se sustituye por telemetría sintética. |

Los pases nativos del HUD aislado y de capturas del juego utilizaron Godot **4.6.3**, Compatibility y Mesa llvmpipe/OpenGL 4.5. El único aviso registrado fue que el controlador no permite cambiar V-Sync. No se observaron errores de script en los registros aprobados. Las comprobaciones geométricas usan el rectángulo transformado del control para incluir la escala del layout.

El flujo de aplicación conserva los 120 pasos físicos por segundo y permite 128 pasos por cuadro dentro del harness para tolerar retrasos del entorno. Espera tanto la entrada de acelerador como un desplazamiento real superior a un metro antes de verificar conducción. Esto pertenece a la prueba, no cambia los límites del juego exportado y no mide FPS de hardware de usuario.

El harness de capturas pausa la simulación después de conducir y mantiene la actualización de cámara para encuadrar, conservando la velocidad real del último estado físico. Es una comprobación visual, no un benchmark de FPS. Su informe terminó sin fallos en `tooling/hud-race-v031-final-data/godot/app_userdata/APEX REBOOT/qa/hud-race/report.json`.

Registros finales consultados: `tooling/hud_v031_layout_native_final.log`, `tooling/hud_v031_intervals_final.log`, `tooling/hud_v031_flow_final.log` y `tooling/hud_v031_race_capture_final.log`. Los scripts y casos están incluidos en el fuente; las capturas de fixtures y los registros temporales quedan fuera de las distribuciones.

La comprobación Web detectó una discrepancia de posición en la cuenta atrás: la cabecera leía el estado inicial de la sesión mientras las filas ya mostraban el orden de parrilla. Se corrigió para actualizar ambos desde la misma clasificación. `tooling/hud_v031_position.log` registra la regresión específica posterior. Las comprobaciones y capturas nativas anteriores a este ajuste siguen descritas con su alcance original; no se presentan como una segunda ejecución de todo el juego.

### Distribución y estado del cierre

Las tres fixtures del empaquetador terminaron correctamente con los nombres 0.3.1 y los avisos OFL/procedencia de Barlow incorporados. `bash -n` aprobó el script de copia de avisos. Estas fixtures no sustituyen la exportación ni la validación de los ZIP finales.

Las exportaciones finales para **Windows x86_64, Linux x86_64 y Web** terminaron con salida 0 después del ajuste de posición, sin errores de script ni de exportación (`tooling/export_v031_final.log`). El ejecutable Linux final cargó su PCK y salió correctamente tras 180 cuadros headless (`tooling/linux_v031_final_startup.log`).

La comprobación Web se realizó en dos fases y conserva sus hashes en `verification_v031.json`:

- **Pase funcional del HUD:** una carrera cargada, acelerador rojo al 100 % y 21 km/h con W, freno rojo al 100 % con S, retorno a cero al soltar, F3 visible y oculto, HUD completo en 960×540 y 1600×900 y pausa con Esc. Este pase precede al último ajuste puntual de la cabecera.
- **Regresión sobre la exportación final:** una instancia nueva del navegador descargó el PCK actualizado. La captura durante la cuenta atrás muestra **3**, cabecera **4 / 4** y jugador en la fila **4**, comprobando el fallo corregido. No se repitió toda la conducción después de ese cambio de texto.

Ambas fases terminaron sin excepciones de página, solicitudes fallidas ni respuestas HTTP de error. El aviso esperado del motor indica que la plantilla Web no incluye occlusion culling. Una captura del primer pase superó el límite de 30 segundos del harness; una captura posterior funcionó y la prueba continuó. Se utilizó Chrome 155 con WebGL/ANGLE y Mesa por software; estas observaciones no son un benchmark de FPS. Las capturas de navegador y los registros son evidencia temporal de desarrollo, fuera de las descargas.

Los paquetes incluyen la documentación actual y los avisos de las fuentes, vehículos y piloto. El empaquetador valida las cabeceras de los ejecutables y PCK/WASM, conserva permisos de ejecución Linux y genera `SHA256SUMS.txt` para los cuatro ZIP.

No se afirma ejecución de Windows nativo, Docker Engine ni GitHub Actions. El rediseño del HUD tampoco acredita nueva precisión física, compatibilidad con todos los dispositivos ni rendimiento de una GPU de usuario.

## Entrega 0.3 · 20 de octubre de 2026

Esta sección distingue las pruebas ejecutadas durante el cierre 0.3 de los resultados históricos conservados debajo. Motor oficial Godot 4.6.3, simulación a 120 Hz y renderizador Compatibility. Ninguna prueba certifica datos de fabricantes ni una vuelta óptima en geometría arbitraria.

### Mecánica, tráfico y reglas

| Comprobación ejecutada | Resultado |
| --- | --- |
| `vehicle_condition_checks.gd` | PASS, 21 comprobaciones de impactos físicos, daño, caída y reparación. Porsche a 13 m/s: daño 26,55 %; Yamaha a 24 m/s:87,64 %, caída y propulsión desactivada. |
| `physics_checks.gd` y `collision_checks.gd` | PASS: suspensión, aceleración, frenada, dirección, moto, pendiente/peralte, barreras a 198 km/h, cuatro parejas coche/moto a 144 km/h y obstáculos sólidos. |
| `audio_contact_probe.gd` | PASS, cinco comprobaciones de PCM: ralentí, golpe físico y respuesta del generador, sin silencio/saturación. Dummy; no equivale a escucha de altavoces ni a grabaciones reales de cada motor. |
| `ai_traffic_checks.gd` | PASS, 32 comprobaciones de carriles, aproximación por detrás, puente, carretera estrecha, frenada, recuperación, clasificación/DNF, replan y alcance proporcional a distancia de frenado. |
| `open_route_ai_checks.gd` | PASS con los cuatro perfiles. Etapa con curvas y pendiente: 27,508/33,825/26,058/23,308 s para Porsche/Yamaha/Ferrari/Senna; error lateral máximo 0,526/0,476/0,641/0,712 m. Se detienen tras la meta. |
| `ai_overtaking_driving_checks.gd` | PASS: Porsche rodea coche detenido sin contacto y regresa a su carril en 9,85 s; desplazamiento lateral máximo 2,807 m y cero recuperación. |
| `ai_recovery_driving_checks.gd` | PASS: coche perpendicular a barrera sale usando marcha atrás real; una maniobra, sin recolocación ni abandono. |
| `traffic_checks.gd` | PASS: carrera de cuatro Porsche, 101,158 s, una vuelta válida y cero recuperaciones; integra modelos, cuenta atrás, colisiones, rebufo y sectores. |
| Yamaha/Sierra Alta/humedad 0,70 | PASS: 150,267 s, error lateral máximo 0,798 m,166,663 km/h máximos, sin caída ni recuperación. |
| `open_route_rules_checks.gd` | PASS: la recuperación explícita conserva solo sectores visitados, no adelanta progreso, permite meta inválida y no concede tiempo récord, medallas, créditos o desbloqueos. Saltos genéricos siguen rechazados. |

Las simulaciones largas preceden al último ajuste puntual del horizonte de detección de tráfico; ese último cambio pasó las 32 comprobaciones de planificación, incluido coche parado a 250 m ante un vehículo a 216 km/h con frenada 3 m/s². No se presentan esos tiempos como otra ejecución de las simulaciones después del ajuste.

### Controles, cámara e interfaz

`controls_camera_checks.gd` pasó 23 comprobaciones usando InputMap, eventos físicos de teclado, entradas analógicas y archivo de preferencias: no duplica eventos, rechaza conflictos, preserva gatillos, cambia la tecla efectiva y aplica curvas independientes. También verifica la apariencia recordada por vehículo, FOV e inclinación sin alterar el cuerpo físico. `motorcycle_camera_checks.gd` conservó sus 18 comprobaciones aprobadas.

El flujo de aplicación `v03_feature_probe.gd` aprobó 32 comprobaciones sin renderizado: garaje, cuatro pestañas de ajustes, reasignación, carrera con cinco rivales, cuenta atrás, movimiento mediante la nueva tecla, pedales, pausa, cambios en carrera, DNF, resultados y vuelta al garaje. La regresión se repitió después de corregir el acceso no soportado al mapa de teclado en modo headless; el segundo registro no contiene errores.

La interfaz se comprobó en 960×540,1024×768,1920×1080 y2560×1080; los resultados de seis participantes también en el tamaño mínimo,4:3 y ultrapanorámico. Se corrigió la posición de la telemetría para dejarla debajo de la clasificación.

La prueba nativa completa también terminó `V03_FEATURE_PROBE PASS`,32 comprobaciones y cero fallos, con acelerador y freno alcanzando 100 %. Se ejecutó con Xvfb/Mesa y entradas de teclado reales del motor. El harness conserva 120 Hz, permite hasta 128 pasos físicos por cuadro para recuperarse de los retrasos del renderizador por CPU y espera a que el cuadro esté dibujado antes de leer el HUD. Durante conducción usa 960×540; las comprobaciones de distribución cubren además las resoluciones indicadas. No modifica esos límites del juego exportado ni presenta el tiempo de este harness como FPS del producto.

### Mundo y capturas

`world_visual_probe.gd` completó cuatro capturas comparables (día seco, día húmedo, noche húmeda y garaje), con salida 0 y sin errores de shader/script. Se corrigieron cielo negro por lectura de cubemap y bandas de autosombra; el preset final Equilibrado usa 2048/dos cascadas con bias adaptado. El entorno continúa siendo procedural y estilizado.

Las capturas de `contact_feedback_probe.gd` muestran marcas de goma, humo y moto/piloto tumbados por un impacto físico. El piloto permanece unido: no es un ragdoll independiente. No se usa generación de imágenes para presentar capturas de la aplicación.

### Exportación y empaquetado

`tools/docker/export.sh all`, ejecutado directamente con el mismo motor y plantillas oficiales que instala el Dockerfile, terminó con salida 0 para Windows x86_64, Linux x86_64 y Web; importación y tres registros de exportación sin `ERROR:` ni `SCRIPT ERROR:`. Se conservaron las firmas de EXE/ELF/PCK/WASM, avisos del piloto y procedencia de los modelos.

El ejecutable Linux exportado arrancó fuera del editor, cargó su PCK y salió correctamente tras 180 cuadros en modo headless. La exportación Windows está generada; un intento bajo Wine falló incluso con `--version`, antes de cargar el proyecto. Ese entorno no permite dar por validado Windows nativo. El workflow manual incluido prepara comprobación en un runner Windows 2022, pero no se ha ejecutado en esta entrega.

La exportación Web 0.3 pasó una comprobación funcional real en Chromium 155.0.8059.84 con WebGL/ANGLE y Mesa: garaje, decoración Original, piloto sobre la Yamaha, cambios de dificultad y respuesta de dirección, pestañas de cámara y controles, entrada en pista, cuenta atrás, cronómetro y movimiento. W mostró acelerador 100 % y 28 km/h; S mostró freno 100 %; Espacio mostró freno trasero 100 %, con los otros dos mandos en cero en cada caso. La moto se detuvo después de frenar y los tres indicadores regresaron a cero al soltar las teclas. HUD, minimapa y ayuda encajaron sin solapamientos ni recortes en 960×540 y 1280×800, con el canvas ajustado al tamaño real del navegador.

No se observaron excepciones JavaScript, errores de shader, solicitudes fallidas ni respuestas HTTP de error en ese pase Web. El único aviso del motor fue la exclusión de occlusion culling en la plantilla Web. La primera captura al entrar al circuito superó el plazo de 30 segundos del harness bajo renderizado por CPU; una captura posterior se completó y la sesión continuó. No es una medición de FPS. El pase 0.3 no repitió consultas externas de elevación ni publicó la aplicación: la comprobación geográfica Web conservada debajo corresponde a 0.2. El resumen y los hashes del build ensayado se registraron en `tooling/web-qa-v03/summary.json`; sus capturas son evidencia temporal de desarrollo, fuera de las distribuciones.

El empaquetador pasó tres pruebas de fixtures (integridad, documentación actual, metadatos, permisos y rechazo de PCK inválido), comprobación sobre entradas reales y filtro de archivos temporales. La configuración Docker, Bash y workflow YAML fueron revisados. No se ejecutó Docker Engine: no hay daemon ni aislamiento de usuarios disponible en este entorno. No se afirma que GitHub Actions o PowerShell hayan corrido.

Los contadores de dibujo y el renderizado por CPU/Mesa no se usan como benchmark de FPS ni como prueba de una GPU, mando, volante o altavoces físicos. Las distribuciones y sus instrucciones están en README_ES.md.

## Historial 0.2

## Versión 0.2: pruebas completadas

Las comprobaciones siguientes corresponden al código fuente v0.2 con Godot 4.6.3 en Linux. Las pruebas físicas usan 120 Hz. Son escenarios reproducibles sobre la implementación; no certifican la precisión de un trazado real, la dinámica de un vehículo comercial ni el funcionamiento de un ejecutable en todos los sistemas.

### Importación geográfica y pendientes

| Prueba | Evidencia y alcance |
| --- | --- |
| [Geografía y análisis](../tests/geo_checks.gd) | `GEO_CHECKS PASS`: 108 aserciones, cero fallos. Proyección local WGS84, orden de coordenadas GeoJSON, GPX con espacios de nombres, separación entre rutas/segmentos, rechazo de entradas inválidas y conservación del original. |
| Cotas y pendientes | La misma prueba comprueba cotas cero/negativas, alturas desconocidas sin convertirlas en cero, cobertura parcial, ascenso y descenso, distancia horizontal frente a distancia 3D, ventana de análisis y pendiente sobre el recorrido horizontal, incluyendo curvas. |
| Geometría construida | La prueba compara el perfil original con el editado; mide el sobrepaso de Catmull–Rom usando el muestreador real de la carretera y comprueba su longitud. Los saltos verticales no producen una pendiente infinita presentada como válida. |
| [Límite de datos](../tests/geo_limits_checks.gd) | `GEO_LIMITS_CHECKS PASS`: conserva 20 000 observaciones originales y su perfil. Una recta sintética se simplifica a dos controles y mantiene el 10 % de pendiente. La ejecución registrada tardó 966 ms; es una observación de este entorno, no una promesa de rendimiento. |

Registros revisados: `geo_checks.log` y `geo_limits_checks.log`. Estas pruebas usan datos sintéticos y archivos de prueba; no acreditan por sí solas la disponibilidad ni la exactitud de servicios cartográficos o de elevación por Internet.

### Recorridos abiertos y regresión de circuitos

| Prueba | Resultado |
| --- | --- |
| [Geometría abierta](../tests/open_route_checks.gd) | `OPEN_ROUTE_CHECKS PASS`. Esquema v2 y metadatos conservados; interpolación lineal sobre los segmentos XYZ originales; extremos limitados sin vuelta al inicio; ausencia de un tramo de cierre inventado; salida/meta separadas, zona de frenada y seis posiciones válidas de parrilla. |
| Límites y validación | La prueba anterior rechaza cotas desconocidas y saltos verticales, permite corregir la geometría sin quedar bloqueada por una advertencia antigua, conserva coordenadas de 39 km y mantiene acotada la malla de terreno en una ruta diagonal larga. Comprueba también el cierre periódico de Costa Clara. |
| [Reglas de etapa](../tests/open_route_rules_checks.gd) | `OPEN_ROUTE_RULES_CHECKS PASS`. Una sola etapa, puertas en orden, tolerancia de meta de 0,5 m, tiempo detenido al terminar, recolocación sin premio, rechazo de saltos de puertas y clasificación de recorridos inválidos. |
| [Reglas de circuito](../tests/race_rules_checks.gd) | Regresión aprobada de los ocho escenarios de vuelta: orden, reversa, saltos, recolocación y progreso. El comportamiento cerrado sigue siendo el predeterminado. |

La [prueba física de IA en ruta abierta](../tests/open_route_ai_checks.gd), repetida después de corregir las colisiones, terminó una etapa válida con cada vehículo mediante acelerador, freno y dirección. No utilizó reposiciones. Tras la meta mantuvo la frenada y se detuvo cerca del extremo, sin comenzar otra vuelta.

| Vehículo | Tiempo de etapa simulado | Desviación lateral máxima | Velocidad 4 s después de meta | Reposiciones |
| --- | ---: | ---: | ---: | ---: |
| Porsche 992 GT3 RS | 27,325 s | 0,540 m | 0,00062 m/s | 0 |
| Yamaha YZF | 33,525 s | 0,477 m | 0,03763 m/s | 0 |

El escenario es una ruta sintética de curvas suaves y variación de altura, con asistencia Sport y ritmo de IA 0,84. La regresión cerrada del Porsche en Costa Clara terminó en 96,442 s, con 1,872 m de desviación lateral máxima y cero reposiciones. Registros: `collision_open_ai_regression.log` y `collision_closed_ai_regression.log`. Estos resultados no garantizan completar cualquier carretera importada ni una trayectoria óptima universal.

### Impactos, suspensión y cámara de moto

La [prueba de colisiones](../tests/collision_checks.gd) dio `COLLISION_CHECKS PASS` tras corregir la envolvente de carrocería y las defensas. El Porsche y la Yamaha contactaron y reaccionaron contra una defensa a 198 km/h sin atravesarla junto al suelo. Cuatro impactos a 144 km/h —coche/coche, moto/coche, coche/moto y moto/moto— registraron contacto y transferencia de velocidad. Consultas físicas confirmaron formas sólidas en pórticos, pilares de viaducto, farolas y troncos. El fallo previo y la configuración vigente se explican en [Colisiones](COLLISIONS.md).

La [regresión física](../tests/physics_checks.gd) dio `PHYSICS CHECKS: PASS`: reposo con cuatro/dos ruedas en contacto, aceleración, frenada, dirección, inclinación de moto y pendiente/peralte. Registros: `collision_fixed.log` y `collision_physics_regression.log`. Se conservaron el centro de masa y la inercia anteriores al ampliar el volumen de choque.

La [prueba de cámara de moto](../tests/motorcycle_camera_checks.gd) dio `MOTORCYCLE_CAMERA_CHECKS PASS`: 18 aserciones, cero fallos. Comprueba inclinación a izquierda/derecha en persecución, depósito y piloto; suma de peralte e inclinación una sola vez; posición de la cabeza; suavizado de rotación; respuesta a la velocidad y conservación del comportamiento de cámara de coches. El registro está en `camera-data/godot/app_userdata/APEX REBOOT/logs/godot.log`. La revisión visual complementaria del piloto y su cámara está registrada abajo.

Para reproducir una prueba, importa primero el proyecto con Godot 4.6.3 y ejecuta desde su carpeta:

```bash
godot --headless --path . --fixed-fps 120 --script tests/collision_checks.gd
```

Sustituye el último argumento por cualquiera de los scripts enlazados. Los registros de desarrollo citados se guardaron en `tooling/`, fuera de las distribuciones; los scripts y sus casos sí forman parte del código fuente.

### QA de interfaz, red y distribuciones v0.2

El pase nativo final `V02_FEATURE_PROBE PASS` completó 11 comprobaciones sin fallos. Se revisaron las imágenes del editor, mapa, HUD y cámara de piloto generadas por Godot. Los resultados históricos v0.1 de abajo no sustituyen estas verificaciones.

| Área | Resultado |
| --- | --- |
| Interfaz | Barras rojas y porcentajes separados; entrada de prueba 65 % acelerador, 30 % freno y 40 % freno trasero. Editor/perfil y HUD encajan en 1280×720, 1024×768, 1920×1080 y 2560×1080. La prueba lee el valor del modelo; no confunde el mando con la fuerza final limitada por neumáticos/ABS. |
| Mapa y editor geográfico | Las 15 teselas de una vista real de Bogotá se cargaron con su atribución. `GEO_UI_CHECKS PASS`: rutas separadas, cotas desconocidas, plano explícito, original conservado, deshacer, JSON y proyección de mapa en ambos hemisferios. |
| HTTPS y caché | SRTM y Copernicus respondieron HTTP 200 desde Godot a dos puntos públicos. `GEO_NETWORK_CHECKS PASS`: 27 comprobaciones sobre conservación/reemplazo de cotas, caché persistente, cancelación, respuestas inválidas, revalidación del mapa y procedencia después de importar/limpiar/cambiar selector. |
| Piloto humano | Quaternius con 65 huesos, montado sobre la Yamaha; postura revisada desde lateral, frente, detrás y cockpit. Nueve combinaciones de velocidad/inclinación conservan los cuatro objetivos de muñecas/tobillos. No se afirma contacto perfecto con todos los polígonos ni animación física de caídas. |
| Exportaciones v0.2 | El mismo `tools/docker/export.sh all`, ejecutado fuera del contenedor con Godot 4.6.3 y sus plantillas oficiales, importó y exportó Windows x86_64, Linux x86_64 y Web. Salida 0 y ningún `ERROR:` en los cuatro registros. Se comprobaron ejecutables, PCK, WASM y avisos del piloto. |
| Ejecutable Linux | El binario exportado arrancó fuera del editor, renderizó con OpenGL/Mesa y completó 180 fotogramas antes de cerrar con salida 0; sin errores. Es una comprobación funcional en renderizado por software, no una medición de FPS de una GPU de usuario. |
| Navegador y ruta real | Chromium 155, WebGL 2 y Mesa: garaje con el nuevo piloto, selector real de GPX, mapa HTTP 200 e importación de cuatro puntos sin cotas. Copernicus respondió HTTP 200 con CORS permitido y diez alturas. El perfil mostró una ruta abierta de 0,34 km, cotas 2553–2556 m, ascenso de 3 m y pendiente máxima de 2,0 % con ventana de 100 m. Se aplicó esa ruta y se entró en pista. |
| Controles Web y tamaño | Después de la cuenta atrás, W mostró 100 % de acelerador y 16 km/h; S, 100 % de freno y 9 km/h; Espacio, 100 % de freno trasero y 0 km/h. Los otros dos controles marcaron 0 % en cada caso. La distancia restante disminuyó y el HUD completo encajó en 1024×768. No hubo errores de página, control ni solicitudes fallidas en el pase final. |
| Windows | Exportación x86_64 generada; no se ejecutó en un sistema Windows. |
| Docker | Configuración Compose y exportador validados, incluido UID sin privilegios en una prueba de exportación. No se ha construido ni ejecutado el contenedor: este entorno carece de Docker Engine. El Dockerfile incluye un paso que comprobará el arranque de Godot dentro de su base cuando se construya. |

La QA Web utilizó una ruta sintética de prueba situada en coordenadas públicas, con cotas consultadas al servicio real. La validación TLS y CORS permaneció activa. Para que Chromium reconociera la CA ya confiada por el entorno, se usó un almacén NSS temporal del navegador; no se cambiaron certificados ni comprobaciones en el juego. El único aviso de Godot correspondió a la exclusión de occlusion culling en la plantilla Web. El registro `web_v02_report.json` y las capturas se conservan como evidencia de desarrollo fuera de las distribuciones. El renderizado por software y la duración de estas pruebas no son una medida de rendimiento para una GPU de usuario.

## Histórico: versión 0.1

Los resultados de esta sección pertenecen a la entrega anterior. Se conservan como referencia y no se presentan como una nueva ejecución de todas las pruebas sobre v0.2.

### Alcance

Se verificó el proyecto con Godot 4.6.3, física a 120 Hz y renderizador Compatibility. Esta es una primera versión jugable y ampliable. Las pruebas comprueban el comportamiento de la implementación; no certifican fidelidad a vehículos reales.

### Pruebas ejecutadas

| Área | Resultado |
| --- | --- |
| Importación de los cuatro modelos | Sin errores de script o importación. |
| Suspensión, neumáticos, transmisión y frenada | Pruebas automáticas aprobadas, incluyendo coches y moto. |
| Representación de la suspensión | Mapeo de pivotes, compresión, reposo, límites y pérdida de contacto comprobados en coche y moto; no altera la física. |
| Recursos OBJ/Mesh | Carga de Mesh/ArrayMesh, normalización de escala/suelo y conservación de materiales comprobadas; un mesh sin piezas separadas no proporciona por sí solo ruedas articuladas. |
| Pendiente y peralte | Prueba con 8° de pendiente y 10° de peralte aprobada. |
| Geometría de pista | Continuidad, espesor, normales, cruces a distintas alturas y ubicación del vehículo aprobados. |
| Editor | Edición de puntos y parámetros, historial y validación aprobados. |
| Reglas de vuelta | Ocho escenarios aprobados: puertas en orden, marcha atrás, saltos, recolocaciones y progreso de carrera. |
| Aerodinámica de estela | Distancia, separación lateral, dirección, altura, límites y ausencia de acumulación ilimitada aprobados. |
| Liveries | Doce decoraciones renderizadas; restaurar Original después de cambiarlas produjo imágenes idénticas a la referencia integrada de cada modelo. |
| Interfaz | Garaje, decoración, carrera diurna/nocturna, editor, ajustes, moto y cámara de piloto revisados en una ventana nativa. |
| Exportación | Windows x86_64, Linux x86_64 y Web generados con las plantillas oficiales de Godot 4.6.3; código de salida 0. |
| Ejecutable Linux | Arranque independiente del editor, en modo sin ventana, con código de salida 0. |
| Ejecutable Windows | Exportación realizada desde Linux; no se ejecutó en un sistema Windows. |
| Navegador Web | Chromium 155 con WebGL 2 y Mesa: garaje con modelos/texturas, entrada en carrera, cuenta atrás, HUD, minimapa y movimiento. Se observó 57 km/h con acelerador al 100 % y el coche avanzando. |
| Audio Web | Se corrigió el tipo de reproducción para el generador procedural. Una nueva entrada en carrera no produjo el aviso de muestreo; no se evaluó calidad audible. |

La revisión gráfica nativa usó OpenGL de Mesa/llvmpipe en una pantalla virtual. No se midió rendimiento representativo de una GPU de usuario. No se anuncian requisitos mínimos ni una cifra de FPS.

### Conducción de IA y rebufo

Los cuatro perfiles completaron vueltas físicas en Costa Clara sin reposiciones. Porsche y Yamaha también completaron Sierra Alta; la prueba de Yamaha en Sierra utilizó humedad 0,70. Los resultados y comandos reproducibles están en [Física e IA](PHYSICS_AND_AI.md).

Una carrera integrada de cuatro Porsche, con colisiones, tres rivales, jugador en piloto automático, rebufo y control de vueltas, terminó con una vuelta válida, cero inválidas y cero reposiciones en 104,475 segundos simulados.

La prueba de rodadura sin acelerador ni freno comenzó a 126 km/h. Tras cinco segundos, el vehículo aislado conservó 117,13 km/h y el seguidor en rebufo 118,01 km/h. El modelo consigue esa diferencia reduciendo la resistencia aerodinámica, sin añadir potencia ni impulsos de velocidad.

### Límites conocidos

- Coeficientes de neumáticos y aerodinámica ajustables, sin calibración con telemetría, CFD o ensayos de cada modelo real.
- La moto utiliza un piloto virtual para el equilibrio; no simula todos los mecanismos de una moto de competición, ni caídas con un piloto articulado físicamente.
- IA determinista con márgenes de seguridad. Puede necesitar ajuste en circuitos extremos creados por el usuario; no garantiza una vuelta óptima universal.
- Entorno y sonido generados de forma procedural, sin capturas fotogramétricas ni grabaciones específicas de cada motor.
- No incluye daños mecánicos completos, desgaste/temperatura de neumáticos, clima dinámico, paradas en boxes, multijugador ni dispositivos de fuerza de retorno.
- Los modelos tienen condiciones de uso diferentes. Consulta [Avisos de terceros](../assets/vehicles/THIRD_PARTY_NOTICES.md).

Las preferencias y el progreso se guardan por usuario. Los datos de pruebas y los archivos temporales del desarrollo no se incluyen en las distribuciones.
